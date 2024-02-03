// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ECDSA} from "nouns-monorepo/external/openzeppelin/ECDSA.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {NounsDAOStorageV3, NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "./interfaces/IERC721Checkpointable.sol";
import {Delegate} from "./Delegate.sol";
import {console2} from "forge-std/console2.sol";//todo

/// @title PropLot Protocol Core
/// @author 📯📯📯.eth
/// @notice The PropLot Protocol Core contract manages a set of deterministic Delegate contracts whose sole purpose
/// is to noncustodially receive delegation from Noun token holders who wish to earn yield in exchange for granting 
/// PropLot the ability to push onchain proposals to the Nouns governance ecosystem. Winning proposals are chosen
/// via a permissionless ERC115 mint managed by the PropLot IdeaHub contract.
/// @notice Since Nouns voting power delegation is all-or-nothing on an address basis, Nounders can only delegate 
/// (and earn yield) on Nouns token balances up to the proposal threshold per wallet address.
    contract PropLot {

    /*
      Structs
    */

    /// @param delegator Only token holder addresses are stored since Delegates can be derived
    /// @param blockDelegated Block at which a Noun was delegated, used for payout calculation.
    /// Only records delegations performed via this contract, ie not direct delegations on Nouns token
    /// @param votingPower Voting power can safely be stored in a uint16 as the type's maximum 
    /// represents 179.5 years of Nouns token supply issuance (at a rate of one per day)
    /// @param delegationId Identifier indicating the recipient Delegate contract given voting power
    /// with another delegation to supplement its votingPower by together delegating to the same proxy
    struct Delegation {
        address delegator;
        uint32 blockDelegated;
        uint32 numCheckpointsSnapshot;
        uint16 votingPower;
        uint16 delegateId;
    }

    struct PropLotSignature {
        address signer;
        uint256 delegateId;
        uint256 nonce;
        uint256 expiry;
        bytes signature;
    }

    /*
      Errors + Events
    */

    error OnlyIdeaContract();
    error InsufficientDelegations();
    error NotDelegated(address nounder, address delegate);
    error ZeroVotesToDelegate(address nounder);
    error DelegateSaturated(uint256 delegateId);
    error InvalidDelegateId(uint256 delegateId);
    error InvalidSignature();
    error OnlyDelegatecallContext();
    error Create2Failure();
    
    event DelegateCreated(address delegate, uint256 id);
    event DelegationRegistered(Delegation optimisticDelegation);
    event DelegationDeleted(Delegation disqualifiedDelegation);
    
    /*
      Constants
    */

    INounsDAOLogicV3 public immutable nounsGovernor;
    IERC721Checkpointable public immutable nounsToken;
    address public immutable ideaTokenHub;
    address private immutable __self;
    bytes32 private immutable __creationCodeHash;

    /*
      Storage
    */

    /// @notice Since delegations can be revoked directly on the Nouns token contract, active delegations are handled optimistically
    Delegation[] private _optimisticDelegations;

    /// @dev Identifier used to derive and refer to the address of Delegate proxy contracts
    /// @notice Declared as `uint16` type to efficiently pack into storage structs, but used as `uint256` or `bytes32`
    /// when used as part of `create2` deployment or other function parameter
    uint16 private _nextDelegateId;

    constructor(address ideaTokenHub_, INounsDAOLogicV3 nounsGovernor_, IERC721Checkpointable nounsToken_) {
        ideaTokenHub = ideaTokenHub_;
        nounsGovernor = nounsGovernor_;
        nounsToken = nounsToken_;
        __self = address(this);
        __creationCodeHash = keccak256(abi.encodePacked(type(Delegate).creationCode, bytes32(uint256(uint160(__self)))));
        
        // increment `_nextDelegateId` and deploy initial Delegate contract 
        _nextDelegateId++;
        createDelegate();
    }

    /// @dev Pushes the winning proposal onto the `nounsGovernor` to be voted on in the Nouns governance ecosystem
    /// Checks for changes in delegation state on `nounsToken` contract and updates PropLot recordkeeping accordingly
    /// @notice May only be called by the PropLot's ERC1155 Idea token hub at the conclusion of each 2-week round
    function pushProposal(
        NounsDAOV3Proposals.ProposalTxs calldata txs,
        string calldata description
    ) public payable {
        if (msg.sender != ideaTokenHub) revert OnlyIdeaContract();
        
        // todo: replace with _updateOptimisticState();
        // to propose, votes must be greater than the proposal threshold
        uint256 minRequiredVotes = INounsDAOLogicV3(nounsGovernor).proposalThreshold() + 1;
        // check for external Nouns transfers or rogue redelegations, update state
        uint256[] memory disqualifiedIndices = _disqualifiedDelegationIndices(minRequiredVotes);
        _deleteDelegations(disqualifiedIndices);

        uint256 len = _optimisticDelegations.length; 
        if (len == 0) revert InsufficientDelegations();

        // find a suitable proposer delegate
        address proposer = _findProposerDelegate(minRequiredVotes);

        if (proposer != address(0x0)) {
            // no event emitted to save gas since NounsGovernor already emits `ProposalCreated`
            Delegate(proposer).pushProposal(nounsGovernor, txs, description);
        } else {
            //todo handle situation where there is no eligible delegate
        }
    }

    /// @dev Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
    /// in a single function call. This is the most convenient option standard wallets using EOA private keys
    /// @notice The Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures and thus
    /// does not support smart contract signatures. In that case, `delegate()` must be called on the Nouns contract directly
    function delegateBySig(PropLotSignature calldata propLotSig) external {
        bytes32 digest = computeNounsDelegationDigest(propLotSig.signer, propLotSig.delegateId, propLotSig.expiry);
        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, propLotSig.signature);
        if (recovered != propLotSig.signer || err != ECDSA.RecoverError.NoError) revert InvalidSignature();

        uint256 votingPower = nounsToken.votesToDelegate(propLotSig.signer);
        if (votingPower == 0) revert ZeroVotesToDelegate(propLotSig.signer);
        uint256 minRequiredVotes = INounsDAOLogicV3(nounsGovernor).proposalThreshold() + 1;
        if (votingPower > minRequiredVotes) votingPower = minRequiredVotes;
        
        address delegate;
        if (propLotSig.delegateId == _nextDelegateId) {
            delegate = createDelegate();
        } else {
            delegate = getDelegateAddress(propLotSig.delegateId);
        }

        // filter outdated signatures to prevent excess delegation- will require new signature
        uint256 currentVotes = nounsToken.getCurrentVotes(delegate);
        if (currentVotes >= minRequiredVotes) revert DelegateSaturated(propLotSig.delegateId);

        Delegation memory delegation = Delegation(propLotSig.signer, uint32(block.number), uint32(nounsToken.numCheckpoints(propLotSig.signer)), uint16(votingPower), uint16(propLotSig.delegateId));
        // emits `DelegationRegistered` event
        _setOptimisticDelegation(delegation);

        nounsToken.delegateBySig(
            delegate, 
            propLotSig.nonce, 
            propLotSig.expiry, 
            uint8(bytes1(propLotSig.signature[64])),
            bytes32(propLotSig.signature[0:32]),
            bytes32(propLotSig.signature[32:64])
        );
    }

    /// @dev Updates this contract's storage to reflect delegations performed directly on the Nouns token contract
    /// @dev Serves as an alternative to `delegateByDelegatecall()` for smart contract wallets
    /// @notice Delegation to must have been performed via a call to the Nouns token contract using either the
    /// `delegate()` or `delegateBySig()` function, having provided the correct Delegate address for the given ID
    function registerDelegation(address nounder, uint256 delegateId) external {
        address delegate = getDelegateAddress(delegateId);
        
        address externalDelegate = nounsToken.delegates(nounder);
        if (externalDelegate != delegate) revert NotDelegated(nounder, delegate);
        
        uint256 votingPower = nounsToken.votesToDelegate(nounder);
        if (votingPower == 0) revert ZeroVotesToDelegate(nounder);

        uint256 minRequiredVotes = INounsDAOLogicV3(nounsGovernor).proposalThreshold() + 1;
        // votingPower above minimum required votes is not usable due to Nouns token implementation constraint
        if (votingPower > minRequiredVotes) votingPower = minRequiredVotes; //todo

        uint32 numCheckpoints = nounsToken.numCheckpoints(nounder);
        
        Delegation memory delegation = Delegation(nounder, uint32(block.number), numCheckpoints, uint16(votingPower), uint16(delegateId));

        // emits `DelegationRegistered` event
        _setOptimisticDelegation(delegation);
    }

    /// @dev Convenience function enabling the bundling of `nounsToken.delegate()` and `this._setoptimisticDelegation()`
    /// into a single transaction, simultaneously performing the token delegation and updating this contract's state
    /// @notice Must be invoked in the context of `delegatecall`
    function delegateByDelegatecall() external {
        if (address(this) == __self) revert OnlyDelegatecallContext();

        uint256 votingPower = uint16(nounsToken.votesToDelegate(address(this)));
        if (votingPower == 0) revert ZeroVotesToDelegate(address(this));

        uint256 minRequiredVotes = INounsDAOLogicV3(nounsGovernor).proposalThreshold() + 1;
        bool isSupplementary;
        if (votingPower < minRequiredVotes) {
            isSupplementary = true;
        } else {
            // votingPower above minimum required votes is not usable due to Nouns token implementation constraint
            votingPower = minRequiredVotes;
        }
        uint256 delegateId = getDelegateId(minRequiredVotes, isSupplementary);
        
        address delegate;
        if (delegateId == _nextDelegateId) {
            // if no Delegate is eligible for supplementing, create a new one
            delegate = PropLot(__self).createDelegate();
        } else {
            delegate = getDelegateAddress(delegateId);
        }

        nounsToken.delegate(delegate);

        // emits `DelegationRegistered` event
        PropLot(__self).registerDelegation(address(this), delegateId);
    }

    /*todo Registers a planned vote, allowing a brief redelegation to the sender for the vote to be cast
    function registerPermittedVote(uint256 delegateId, uint256 proposalId) public {
        // check delegate exists and is delegated to by the sender
        // check that sender has not yet voted on given proposalId: require(nounsToken.proposals(proposalId).receipts(msg.sender).hasVoted == false)
        // store proposalId and new expected numCheckpoints (incremented) so they can later be validated
        // todo: how much time should be provided for the vote? 2 hours?
        // add logic at settlement time for verifying against nounsToken.proposals(proposalId).receipts(msg.sender)
    }
    */

    /// @dev Deploys a Delegate contract deterministically via `create2`, using the `_nextDelegateId` as salt
    /// @notice As the constructor argument is appended to bytecode, it affects resulting address, eliminating risk of DOS vector
    function createDelegate() public returns (address delegate) {
        uint256 nextDelegateId = uint256(_nextDelegateId);
        delegate = address(new Delegate{salt: bytes32(nextDelegateId)}(__self));

        if (delegate == address(0x0)) revert Create2Failure();        
        _nextDelegateId++;
    
        emit DelegateCreated(delegate, nextDelegateId);
    }

    /*
      Views
    */

    /// @dev Computes the counterfactual address for a given delegate ID whether or not it has been deployed
    function getDelegateAddress(uint256 delegateId) public view returns (address delegate) {
        if (delegateId == 0) revert InvalidDelegateId(delegateId);
        delegate = _simulateCreate2(bytes32(uint256(delegateId)), __creationCodeHash);
    }

    /// @dev Returns either an existing delegate ID if one meets the given parameters, otherwise returns the next delegate ID
    /// @param minRequiredVotes Minimum votes to make a proposal. Must be more than current proposal threshold which is based on Nouns token supply 
    /// @param isSupplementary Whether or not to search for a Delegate that doesn't meet the current proposal threshold
    function getDelegateId(uint256 minRequiredVotes, bool isSupplementary) public view returns (uint256 delegateId) {
        delegateId = _findDelegateId(minRequiredVotes, isSupplementary);
    }

    /// @dev Typecasts and returns the next delegate ID as a `uint256`
    function getNextDelegateId() public view returns (uint256 nextDelegateId) {
        return uint256(_nextDelegateId);
    }

    /// @dev Returns a suitable delegate address for an account based on its voting power
    function getSuitableDelegateFor(address nounder, uint256 minRequiredVotes) external view returns (address delegate) {
        uint256 votingPower = nounsToken.votesToDelegate(nounder);
        bool isSupplementary;
        if (votingPower < minRequiredVotes) isSupplementary = true;

        uint256 delegateId = getDelegateId(minRequiredVotes, isSupplementary);
        delegate = getDelegateAddress(delegateId);
    }

    /// @dev Returns all existing Delegates with voting power below the minimum required to make a proposal
    /// Provided to improve offchain devX; returned values can change at any time as Nouns ecosystem is external
    function getAllPartialDelegates(uint256 minRequiredVotes) external view returns (address[] memory partialDelegates) {
        uint256 numPartialDelegates;
        uint256 nextDelegateId = _nextDelegateId;
        // determine size of memory array
        for (uint256 i = 1; i < nextDelegateId; ++i) {
            address delegateAddress = getDelegateAddress(i);
            uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

            if (currentVotes < minRequiredVotes) {
                numPartialDelegates++;
            }
        }

        // populate memory array
        partialDelegates = new address[](numPartialDelegates);
        uint256 index;
        for (uint256 j = 1; j < nextDelegateId; ++j) {
            address delegateAddress = getDelegateAddress(j);
            uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

            if (currentVotes < minRequiredVotes) {
                partialDelegates[index] = delegateAddress;
                index++;
            }
        }
    }
    /// @dev Returns all existing Delegates currently eligible for making a proposal
    /// Provided to improve offchain devX: returned values can change at any time as Nouns ecosystem is external
    function getAllEligibleProposerDelegates(uint256 minRequiredVotes) external view returns (address[] memory eligibleProposers) {
        uint256 numEligibleProposers;
        uint256 nextDelegateId = _nextDelegateId;
        // determine size of memory array
        for (uint256 i = 1; i < nextDelegateId; ++i) {
            address delegateAddress = getDelegateAddress(i);
            bool noActiveProp = _checkForActiveProposal(delegateAddress);
            uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

            if (noActiveProp && currentVotes >= minRequiredVotes) {
                numEligibleProposers++;
            }
        }

        // populate memory array
        eligibleProposers = new address[](numEligibleProposers);
        uint256 index;
        for (uint256 j = 1; j < nextDelegateId; ++j) {
            address delegateAddress = getDelegateAddress(j);
            bool noActiveProp = _checkForActiveProposal(delegateAddress);
            uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

            if (noActiveProp && currentVotes >= minRequiredVotes) {
                eligibleProposers[index] = delegateAddress;
                index++;
            }
        }
    }

    /// @dev Convenience function to facilitate offchain development by computing the `delegateBySig()` digest 
    /// for a given signer and expiry
    function computeNounsDelegationDigest(address signer, uint256 delegateId, uint256 expiry) public view returns (bytes32 digest) {
        bytes32 nounsDomainTypehash = nounsToken.DOMAIN_TYPEHASH();
        string memory nounsName = nounsToken.name();
        bytes32 nounsDomainSeparator = keccak256(
            abi.encode(
                nounsDomainTypehash,
                keccak256(bytes(nounsName)),
                block.chainid,
                nounsToken
            )
        );

        address delegate = getDelegateAddress(delegateId);
        uint256 signerNonce = nounsToken.nonces(signer);
        bytes32 nounsDelegationTypehash = nounsToken.DELEGATION_TYPEHASH();
        bytes32 structHash = keccak256(
            abi.encode(
                nounsDelegationTypehash, 
                delegate, 
                signerNonce, 
                expiry
            )
        );

        digest = ECDSA.toTypedDataHash(nounsDomainSeparator, structHash);
    }

    /*
      Internals
    */

    /// @dev Returns the id of the first delegate ID found to meet the given parameters
    /// To save gas by minimizing costly SLOADs, terminates as soon as a delegate meeting the critera is found
    /// @param _minRequiredVotes The votes needed to make a proposal, dynamic based on Nouns token supply
    /// @param _isSupplementary Whether or not the returned Delegate should accept fewer than required votes
    function _findDelegateId(uint256 _minRequiredVotes, bool _isSupplementary) internal view returns (uint256 delegateId) {
        // cache in memory to reduce SLOADs
        uint256 nextDelegateId = _nextDelegateId;
        // bounded by (Nouns token supply / proposal threshold)
        unchecked {
            for (uint256 i; i < nextDelegateId; ++i) {
                uint256 currentDelegateId = i + 1;
                address delegateAddress = getDelegateAddress(currentDelegateId);
                uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

                // when searching for supplement delegate ID, return if additional votes are required
                if (_isSupplementary && currentVotes < _minRequiredVotes) return currentDelegateId;
                // when searching for solo delegate ID, return if votes are 0
                if (!_isSupplementary && currentVotes == 0) return currentDelegateId;
            }
        }

        // if no existing Delegates match the criteria, a new one must be created
        delegateId = nextDelegateId;
    }

    /// @dev Returns the first Delegate found to be eligible for pushing a proposal to Nouns governance
    function _findProposerDelegate(uint256 _minRequiredVotes) internal view returns (address proposerDelegate) {
        // cache in memory to reduce SLOADs
        uint256 nextDelegateId = _nextDelegateId;
        // bounded by Nouns token supply / proposal threshold
        unchecked {
            // delegate IDs start at 1
            for (uint256 i = 1; i < nextDelegateId; ++i) {
                address currentDelegate = getDelegateAddress(i);
                
                // check for active proposals
                bool noActiveProp = _checkForActiveProposal(currentDelegate);
                
                // Delegations with active proposals are unable to make additional proposals
                if (noActiveProp == false) continue;

                uint256 currentVotingPower = nounsToken.getCurrentVotes(currentDelegate);
                if (currentVotingPower < _minRequiredVotes) continue;

                // if checks pass, return eligible delegate
                return currentDelegate;
            }
        }
    }

    /// @dev Returns an array of delegation IDs that violated the protocol rules and are ineligible for yield
    function _disqualifiedDelegationIndices(uint256 _minRequiredVotes) internal returns (uint256[] memory) {
        // cache _optimisticDelegations to memory to reduce SLOADs for potential event & gas optimization
        Delegation[] memory optimisticDelegations = _getOptimisticDelegations();
        bool[] memory disqualifyingIndices = new bool[](optimisticDelegations.length);
        uint256 numDisqualifiedIndices;
        
        // array length is bounded by Nouns token supply and will not overflow for eons
        unchecked {
            // search for number of disqualifications
            for (uint256 i; i < optimisticDelegations.length; ++i) {
                address nounder = optimisticDelegations[i].delegator;
                address delegate = getDelegateAddress(optimisticDelegations[i].delegateId);
                
                bool disqualify;
                uint256 currentCheckpoints = nounsToken.numCheckpoints(nounder);
                if (currentCheckpoints != optimisticDelegations[i].numCheckpointsSnapshot) {
                    //todo handle supplements so that legitimate supplementers are not penalized for pairing with violators
                    disqualify = _inspectCheckpoints(nounder, delegate, currentCheckpoints, optimisticDelegations[i].numCheckpointsSnapshot, optimisticDelegations[i].votingPower, _minRequiredVotes);
                    
                    if (disqualify == true) {
                        disqualifyingIndices[i] = true;
                        ++numDisqualifiedIndices;
                    }
                }
            }

            // if found, populate array of disqualifications
            if (numDisqualifiedIndices > 0) {
                uint256[] memory disqualifiedIndices = new uint256[](numDisqualifiedIndices);
                uint256 j;
                uint256 index;
                // loop until last member of disqualifiedIndices is populated
                while (index != numDisqualifiedIndices) {
                    if (disqualifyingIndices[j] == true) {
                        disqualifiedIndices[index] = j;
                        ++index;
                    }
                    ++j;
                }

                return disqualifiedIndices;
            } else {
                return new uint[](0);
            }
        }
    }

    //todo add return param to mark which supplement violated protocol rules and granularly disqualify
    function _inspectCheckpoints(address _nounder, address _delegate, uint256 _currentCheckpoints, uint256 _numCheckpointsSnapshot, uint256 _votingPower, uint256 _minRequiredVotes) internal view returns (bool _disqualify) {
        // Nouns token contract uses safe Uint32 math, preventing underflow
        uint256 delta = _currentCheckpoints - _numCheckpointsSnapshot;
        unchecked {
            for (uint256 j; j < delta; ++j) {
                // (uint32 fromBlock, uint96 votes)
                IERC721Checkpointable.Checkpoint memory checkpoint = nounsToken.checkpoints(_nounder, uint32(_currentCheckpoints - j - 1));
                
                // disqualify redelegations and transfers/burns that dropped voting power below recorded value
                uint256 checkpointVotes = nounsToken.getPriorVotes(_delegate, checkpoint.fromBlock);
                //todo bug in disqualifications, test each delegator in supplement ie if (checkpointVotes < _minRequiredVotes)
                if (checkpointVotes < _votingPower || checkpoint.votes < _votingPower) {
                    _disqualify = true;
                    break;
                }
            }
        }
    }

    /// @dev Deletes Delegations by swapping the non-final index members to be removed with members to be preserved
    function _deleteDelegations(uint256[] memory _indices) internal {
        // bounded by Noun token supply and will not overflow
        unchecked {
            for (uint256 i; i < _indices.length; ++i) {
                // will not underflow as this function is only invoked if delegation indices were found
                uint256 lastIndex = _optimisticDelegations.length - 1;
                uint256 indexToDelete = _indices[i];

                Delegation memory currentDelegation = _optimisticDelegations[indexToDelete];

                if (indexToDelete != lastIndex) {
                    // replace Delegation to be deleted with last member of array
                    _optimisticDelegations[indexToDelete] = _optimisticDelegations[lastIndex];
                }
                _optimisticDelegations.pop();
        
                emit DelegationDeleted(currentDelegation);
            }
        }
    }

    /// @notice Marked internal since Delegations recorded in storage are optimistic and should not be relied on externally
    function _getOptimisticDelegations() internal view returns (Delegation[] memory) {
        return _optimisticDelegations;
    }

    function _setOptimisticDelegation(Delegation memory _delegation) internal {
        _optimisticDelegations.push(_delegation);

        emit DelegationRegistered(_delegation);
    }

    /// @dev Returns true when an active proposal exists for the delegate, meaning it is ineligible to propose
    function _checkForActiveProposal(address delegate) internal view returns (bool _noActiveProp) {
        uint256 delegatesLatestProposal = INounsDAOLogicV3(nounsGovernor).latestProposalIds(delegate);
        if (delegatesLatestProposal != 0) {
            _noActiveProp =_isEligibleProposalState(delegatesLatestProposal);
        } else {
            _noActiveProp = true;
        }
    }

    /// @dev References the Nouns governor contract to determine whether a proposal is in a disqualifying state
    function _isEligibleProposalState(uint256 _latestProposal) internal view returns (bool) {
        NounsDAOStorageV3.ProposalState delegatesLatestProposalState = INounsDAOLogicV3(nounsGovernor).state(_latestProposal);
        if (
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.ObjectionPeriod ||
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Active ||
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Pending ||
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Updatable
        ) return false;

        return true;
    }

    /// @dev Computes a counterfactual Delegate address via `create2` using its creation code and `delegateId` as salt
    function _simulateCreate2(bytes32 _salt, bytes32 _creationCodeHash) internal view returns (address simulatedDeployment) {
        address self = __self;

        assembly {
            let ptr := mload(0x40) // instantiate free mem pointer

            // populate memory in small-Endian order to prevent `self` from overwriting the `0xff` prefix byte
            mstore(add(ptr, 0x40), _creationCodeHash) // insert 32-byte creationCodeHash at 64th offset
            mstore(add(ptr, 0x20), _salt) // insert 32-byte salt at 32nd offset
            mstore(ptr, self) // insert 20-byte deployer address at 12th offset
            let startOffset := add(ptr, 0x0b) // prefix byte `0xff` must be inserted after `self` so it is not overwritten
            mstore8(startOffset, 0xff) // insert single byte create2 constant at 11th offset within `ptr` word

            simulatedDeployment := keccak256(startOffset, 85)
        }
    }
}
