// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ECDSA} from "nouns-monorepo/external/openzeppelin/ECDSA.sol";
import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";
import {NounsDAOLogicV3} from "nouns-monorepo/governance/NounsDAOLogicV3.sol";
import {NounsDAOStorageV3, NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {ERC721Checkpointable} from "nouns-monorepo/base/ERC721Checkpointable.sol";
import {Delegate} from "./Delegate.sol";
import {console2} from "forge-std/console2.sol";

contract PropLotCore {
    // Nounder calls this contract to generate a proxy and delegates voting power to it
    // For utmost security, the Delegate contains no functionality beyond pushing proposals into Noun governance 
    // This democratizes access to publicizing ideas for Nouns governance to any address by lending proposal power 
    // and lowering the barrier of entry to submitting onchain proposals. Competition is introduced by an auction
    // of ERC1155s, each representing an idea for a proposal. 

    // since Nouns voting power delegation is all-or-nothing on an address basis, 


    // proposals -> 1155s that non-nounders can mint for a fee in support of (provenance + liquidity)
    // 1155 w/ most mints wins onchain, two week proposal 'ritual' to push ideas onchain based on highest mints
    // split sum of minting fees between existing noun delegates in a claim() func
    // non-winning tokens w/ existing votes can roll over into following two week periods
    // enable pooling of delegation power so that eg 2 nounders who only own 1 noun each can pool their power to propose  
    
    // todo: handle updates of votingPower changes
    // todo: user create interfaces for ERC721Checkpointable and ERC721Votes
    // todo: must inherit erc721receiver if receiving tokens to enable delegation of partial vote balance

    /*
      Structs
    */

    /// @param delegator Only token holder addresses are stored since Delegates can be derived
    /// @param blockDelegated Block at which a Noun was delegated, used for payout calculation.
    /// Only records delegations performed via this contract, ie not direct delegations on Nouns token
    /// @param votingPower Voting power can safely be stored in a uint16 as the type's maximum 
    /// represents 179.5 years of Nouns token supply issuance (at a rate of one per day)
    /// @param supplementId Identifier used to combine a delegation with votingPower below the proposalThreshold
    /// with another delegation to supplement its votingPower by together delegating to the same proxy
    struct Delegation {
        address delegator;
        uint32 blockDelegated;
        uint32 numCheckpointsSnapshot;
        uint16 votingPower;
        uint16[] supplementIds;
    }

    /*
      Errors + Events
    */

    error OnlyIdeaContract();
    error InsufficientDelegations();
    error NotDelegated(address nounder, address delegate);
    error ECDSAInvalidSignatureLength(uint256 length);
    error OnlyDelegatecallContext();
    error Create2Failure();
    
    event DelegateCreated(address nounder, address delegate);
    event DelegationActivated(Delegation activeDelegation);
    event DelegationDeleted(Delegation inactiveDelegation);
    
    /*
      Constants
    */

    address public immutable ideaTokenHub;
    address payable public immutable nounsGovernor;
    address public immutable nounsToken;
    address private immutable __self;

    /*
      Storage
    */

    /// @notice Since delegations can be revoked directly on the Nouns token contract, active delegations are handled optimistically
    Delegation[] private _activeDelegations;
    
    /// @dev Packed storage of `supplementId`s awaiting supplement matchmaking to reach `proposalThreshold`, akin to a `uint16[]`array
    /// @notice Can store up to 16 `supplementId` members for async processing- enough for 18 years when proposalThreshold reaches 17
    ///todo implement buckets to increase lifespan of this bitField
    bytes32 eligibleSupplementsBitField;
    uint16 currentSupplementId;

    /// @dev Returns the Supplement information associated with a supplement delegation
    mapping (uint16 => Delegation) public supplementDelegations;

    constructor(address ideaTokenHub_, address payable nounsGovernor_, address nounsToken_) {
        ideaTokenHub = ideaTokenHub_;
        nounsGovernor = nounsGovernor_;
        nounsToken = nounsToken_;
        __self = address(this);
    }

    /// @dev Pushes the winning proposal onto the `nounsGovernor` to be voted on in the Nouns governance ecosystem
    /// Checks for changes in delegation state on `nounsToken` contract and updates PropLot recordkeeping accordingly
    /// @notice May only be called by the PropLot's ERC1155 Idea token hub at the conclusion of each 2-week round
    /// todo: rename to finalizeRound() and convert proposal pushing to internal function
    function pushProposal(
        NounsDAOV3Proposals.ProposalTxs calldata txs,
        string calldata description
    ) public payable {
        if (msg.sender != ideaTokenHub) revert OnlyIdeaContract();
        
        // check for external Nouns transfers or rogue redelegations, update state
        _resolveOptimisticState();
        _disqualifiedDelegationIndices();
        //todo find way for supplementDelegations to handle increased proposal threshold:
        // check current value of numCheckpoints, if higher check voting power at time of each new checkpoint with getPriorVotes to ensure votingPower never dropped
        // todo: _updateDelegations();

        uint256 len = _activeDelegations.length; 
        if (len == 0) revert InsufficientDelegations();

        uint256 proposalThreshold = NounsDAOLogicV3(nounsGovernor).proposalThreshold();
        // find a suitable proposer delegate
        address proposer;
        bool noActiveProp;
        bool checkpointDisqualified;
        unchecked {
            for (uint256 i; i < len; ++i) {
                Delegation memory currentDelegation = _activeDelegations[i];
                
                address delegate = getDelegateAddress(currentDelegation.delegator);
                // check for active proposals
                uint256 delegatesLatestProposal = NounsDAOLogicV3(nounsGovernor).latestProposalIds(delegate);
                if (delegatesLatestProposal != 0) {
                    noActiveProp =_isEligibleProposalState(delegatesLatestProposal);
                } else {
                    noActiveProp = true;
                }
                
                // Delegations with active proposals are unable to make additional proposals
                if (noActiveProp == false) continue;

                uint256 currentVotingPower = NounsDAOLogicV3(nounsGovernor).getCurrentVotes(delegate);
                if (currentVotingPower < proposalThreshold) continue;
          
                proposer = delegate;
                break;            }
        }
        if (proposer != address(0x0)) {
            Delegate(proposer).pushProposal(nounsGovernor, txs, description);
        } else {
            //todo handle situation where there is no eligible delegate
        }
    }

    /// @dev Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
    /// in a single function call. This is the most convenient option standard wallets using EOA private keys
    /// @notice The Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures and thus
    /// does not support smart contract signatures. In that case, `delegate()` must be called on the Nouns contract directly
    function delegateBySig(uint256 nonce, uint256 expiry, address signer, bytes calldata signature) external {
        bytes32 digest = computeNounsDelegationDigest(signer, expiry);
        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, signature);
        if (recovered != signer || err != ECDSA.RecoverError.NoError) revert InvalidSignature();
        
        //todo: check if votesToDelegate(msg.sender) is < proposalThreshold, add to supplement mapping
        address delegate = getDelegateAddress(signer);
        if (delegate.code.length == 0) {
            createDelegate(signer);
        }

        uint32 numCheckpoints = uint32(NounsDAOLogicV3(nounsGovernor).numCheckpoints());
        uint16 votingPower = uint16(ERC721Checkpointable(nounsToken).votesToDelegate(msg.sender));
        uint256 proposalThreshold = NounsDAOLogicV3(nounsGovernor).proposalThreshold();
        // votingPower above proposalThreshold is not usable for protocol due to Nouns token implementation
        if (votingPower > proposalThreshold) votingPower = proposalThreshold;

        uint16 supplementId;//TODO: matchmaking 
        Delegation memory delegation = Delegation(signer, uint32(block.number), numCheckpoints, votingPower, supplementId);
        _setActiveDelegation(delegation);

        ERC721Checkpointable(nounsToken).delegateBySig(
            delegate, 
            nonce, 
            expiry, 
            uint8(bytes1(signature[64])),
            bytes32(signature[0:32]),
            bytes32(signature[32:64])
        );
    }

    /// @dev Updates this contract's storage to reflect delegations performed directly on the Nouns token contract
    /// @dev Serves as an alternative to `delegateByDelegatecall()` for smart contract wallets
    /// @notice Delegation to must have been performed via a call to the Nouns token contract using either the
    /// `delegate()` or `delegateBySig()` function, having provided the correct proxy address for the Noun holder address
    function setActiveDelegation(address nounder) external {
        //todo: check if votesToDelegate(nounder) is < proposalThreshold, add to supplement mapping
        address delegate = getDelegateAddress(nounder);
        address externalDelegate = ERC721Checkpointable(nounsToken).delegates(nounder);
        if (externalDelegate != delegate) revert NotDelegated(nounder, delegate);
        
        if (delegate.code.length == 0) {
            createDelegate(nounder);
        }

        uint32 numCheckpoints = ERC721Checkpointable(nounsToken).numCheckpoints();
        uint16 votingPower = uint16(ERC721Checkpointable(nounsToken).votesToDelegate(address(this)));
        uint256 proposalThreshold = NounsDAOLogicV3(nounsGovernor).proposalThreshold();
        // votingPower above proposalThreshold is not usable for protocol due to Nouns token implementation
        if (votingPower > proposalThreshold) votingPower = proposalThreshold;
        
        uint16 supplementId;//TODO: matchmaking
        Delegation memory delegation = Delegation(address(this), uint32(block.number), numCheckpoints, votingPower, supplementId);

        _setActiveDelegation(delegation);
    }

    /// @dev Convenience function enabling the bundling of `nounsToken.delegate()` and `this._setActiveDelegation()`
    /// into a single transaction, simultaneously performing the token delegation and updating this contract's state
    /// @notice Must be invoked in the context of `delegatecall`
    function delegateByDelegatecall() external {
        if (address(this) == __self) revert OnlyDelegatecallContext();

        //todo: check if votesToDelegate(msg.sender) is < proposalThreshold, add to supplement mapping
        address delegate = getDelegateAddress(address(this));
        if (delegate.code.length == 0) {
            // will revert on `create2` failure
            PropLotCore(__self).createDelegate(address(this));
        }

        uint32 numCheckpoints = ERC721Checkpointable(nounsToken).numCheckpoints();
        uint16 votingPower = uint16(ERC721Checkpointable(nounsToken).votesToDelegate(address(this)));
        uint16 supplementId;//TODO: matchmaking
        Delegation memory delegation = Delegation(address(this), uint32(block.number), numCheckpoints, votingPower, supplementId);

        ERC721Checkpointable(nounsToken).delegate(delegate);

        PropLotCore(__self).setActiveDelegation(address(this));
    }

    /// @dev Deploys a Delegate contract on behalf of `nounder`
    function createDelegate(address nounder) public returns (address delegate) {
        // todo handle supplements
        delegate = address(new Delegate{salt: bytes32(uint256(uint160(nounder)))}(__self));

        if (delegate == address(0x0)) revert Create2Failure();
        
        emit DelegateCreated(nounder, delegate);
    }

    /*
      Views
    */

    function getDelegateAddress(address nounder) public view returns (address delegate) {
        if (supplementDelegates[delegate] != address(0x0)) return supplementDelegates[nouner]; 

        //todo: hard code into storage as constant for gas optimization
        bytes32 creationCodeHash = keccak256(abi.encodePacked(type(Delegate).creationCode, bytes32(uint256(uint160(__self)))));
        delegate = _simulateCreate2(bytes32(uint256(uint160(nounder))), creationCodeHash);
    }

    /// @dev Convenience function to facilitate offchain development by computing the `delegateBySig()` digest 
    /// for a given signer and expiry
    function computeNounsDelegationDigest(address signer, uint256 expiry) public view returns (bytes32 digest) {
        bytes32 nounsDomainTypehash = ERC721Checkpointable(nounsToken).DOMAIN_TYPEHASH();
        string memory nounsName = ERC721Checkpointable(nounsToken).name();
        bytes32 nounsDomainSeparator = keccak256(
            abi.encode(
                nounsDomainTypehash,
                keccak256(bytes(nounsName)),
                block.chainid,
                nounsToken
            )
        );

        address delegate = getDelegateAddress(signer);
        uint256 signerNonce = ERC721Checkpointable(nounsToken).nonces(signer);
        bytes32 nounsDelegationTypehash = ERC721Checkpointable(nounsToken).DELEGATION_TYPEHASH();
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

    function _getActiveDelegations() internal view returns (Delegation[] memory) {
        return _activeDelegations;
    }

    //todo add supplementId param to mark which supplement violated protocol rules and granularly disqualify
    function _inspectCheckpoints(address _nounder, address _delegate, uint256 _currentCheckpoints, uint256 _numCheckpointsSnapshot, uint256 _votingPower) internal view returns (bool _disqualify) {
        // cannot underflow as Nouns token contract uses safe Uint32 math
        uint256 delta = _currentCheckpoints - _numCheckpointsSnapshot;
        for (uint256 j; j < delta; ++j) {
            (uint32 fromBlock, uint96 votes) = ERC721Checkpointable(nounsToken).checkpoints((_nounder, _currentCheckpoints - j - 1));
            
            // disqualify redelegations and transfers/burns that dropped voting power below recorded value
            uint256 checkpointVotes = ERC721Checkpointable(nounsToken).getPriorVotes(_delegate, fromBlock);
            if (checkpointVotes < _votingPower || votes < _votingPower) {
                _disqualify = true;
                break;
            }
        }
    }

    function _disqualifiedDelegationIndices(uint256 _proposalThreshold) internal returns (uint256[] memory) {
        // cache _activeDelegations to memory to reduce SLOADs for potential event & gas optimization
        Delegation[] memory activeDelegations = getActiveDelegations();
        bool[] memory disqualifyingIndices = new bool[](activeDelegations.length);
        uint256 numDisqualifiedIndices;
        
        // array length is bounded by Nouns token supply and will not overflow for eons
        unchecked {
            // search for number of disqualifications
            for (uint256 i; i < activeDelegations.length; ++i) {
                address nounder = currentDelegation[i].delegator;
                address delegate = getDelegateAddress(nounder);
                
                bool disqualify;
                uint256 currentCheckpoints = ERC721Checkpointable(nounsToken).numCheckpoints(nounder);
                if (currentCheckpoints != currentDelegation[i].numCheckpointsSnapshot) {
                    //todo handle supplements so that legitimate supplementers are not penalized for pairing with violators
                    disqualify = _inspectCheckpoints(nounder, delegate, currentCheckpoints, currentDelegation[i].numCheckpointsSnapshot, votingPower);
                    
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
                return;
            }
        }
    }

    function _deleteDelegations(uint256[] memory _indices) internal {
    
        //todo turn into _deleteDelegation() internal func
        if (ERC721Checkpointable(nounsToken).delegates(nounder) != delegate) {
            uint256 lastIndex = _activeDelegations.length - 1;
            if (i < lastIndex) {
                Delegation memory lastDelegation = _activeDelegations[lastIndex];
                _activeDelegations[i] = lastDelegation;
                ++numDisqualifiedIndices;
            }

            emit DelegationDeleted(currentDelegation);
        }

        if (currentDelegation.supplementId != 0) {
            uint16[] memory currentSupplements = _activeSupplements[delegate];
            uint256 supplementsLen = currentSupplements.length;
            // loop starting from second index
            for (uint256 j = 1; j < supplementsLen; ++j) {
                // bypass getDelegateAddress() to save on SLOAD
                address supplementDelegate = _simulateCreate2();
                _inspectCheckpoints(currentSupplements[j]);
            }
        } else {

            // disqualifiedCheckpoint = _inspectCheckpoints(currentDelegation) // allow for Noun votingPower fungibility? (eg: 1 -> 2 -> 1)
            // upon finding disqualifiedCheckpoint, still try to propose but exclude currentDelegation from yield as punishment
            }

                        // delete inactive delegations from rightmost to leftmost
        uint256 startIndex = len - 1;
        for (uint256 j; j < numInactiveNonLastIndices; ++j) {
            delete _activeDelegations[startIndex - j];
            //todo
            // if (_supplementDelegations[nounder] != address(0x0)) delete _supplementDelegations[nounder];
        }
        }
    }

    function _setActiveDelegation(Delegation memory _delegation) internal {
        _activeDelegations.push(_delegation);

        emit DelegationActivated(_delegation);
    }

    function _isEligibleProposalState(uint256 _latestProposal) internal returns (bool _noActivePro) {
        NounsDAOStorageV3.ProposalState delegatesLatestProposalState = NounsDAOLogicV3(nounsGovernor).state(delegatesLatestProposal);
        if (
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.ObjectionPeriod ||
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Active ||
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Pending ||
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Updatable
        ) return;

        _eligible = true;
    }

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
