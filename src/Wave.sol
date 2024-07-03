// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {UUPSUpgradeable} from "lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "nouns-monorepo/external/openzeppelin/ECDSA.sol";
import {INounsDAOLogicV3} from "src/interfaces/INounsDAOLogicV3.sol";
import {NounsDAOStorageV3, NounsTokenLike} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";
import {IERC721Checkpointable} from "./interfaces/IERC721Checkpointable.sol";
import {IWave} from "./interfaces/IWave.sol";
import {IIdeaTokenHub} from "./interfaces/IIdeaTokenHub.sol";
import {Delegate} from "./Delegate.sol";

/// @title Wave Protocol Core
/// @author 📯📯📯.eth
/// @notice The Wave Protocol Core contract manages a set of deterministic Delegate contracts whose sole purpose
/// is to noncustodially receive delegation from Noun token holders who wish to earn yield in exchange for granting
/// Wave the ability to push onchain proposals to the Nouns governance ecosystem. Winning proposals are chosen
/// via a permissionless ERC115 mint managed by the Wave IdeaHub contract.
/// @notice Since Nouns voting power delegation is all-or-nothing on an address basis, Nounders can only delegate
/// (and earn yield) on Nouns token balances up to the proposal threshold per wallet address.
contract Wave is Ownable, UUPSUpgradeable, IWave {
    /*
      Constants
    */

    INounsDAOLogicV3 public nounsGovernor;
    IERC721Checkpointable public nounsToken;
    bytes32 private immutable __creationCodeHash;

    /*
      Storage
    */

    IIdeaTokenHub public ideaTokenHub;

    /// @notice Since delegations can be revoked directly on the Nouns token contract, active delegations are handled optimistically
    Delegation[] private _optimisticDelegations;

    /// @dev Identifier used to derive and refer to the address of Delegate proxy contracts
    /// @notice Declared as `uint16` type to efficiently pack into storage structs, but used as `uint256` or `bytes32`
    /// when used as part of `create2` deployment or other function parameter
    uint16 private _nextDelegateId;

    /*
      Wave
    */

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address ideaTokenHub_,
        address nounsGovernor_,
        address nounsToken_,
        uint256 minSponsorshipAmount_,
        uint256 waveLength_,
        address renderer_
    ) public virtual initializer {
        _transferOwnership(msg.sender);

        ideaTokenHub = IIdeaTokenHub(ideaTokenHub_);
        ideaTokenHub.initialize(msg.sender, nounsGovernor_, minSponsorshipAmount_, waveLength_, renderer_, '');
        nounsGovernor = INounsDAOLogicV3(nounsGovernor_);
        nounsToken = IERC721Checkpointable(nounsToken_);
        __creationCodeHash =
            keccak256(abi.encodePacked(type(Delegate).creationCode, bytes32(uint256(uint160(address(this))))));

        // increment `_nextDelegateId` and deploy initial Delegate contract
        _nextDelegateId++;
        createDelegate();
    }

    /// @inheritdoc IWave
    function delegateBySig(WaveSignature calldata waveSig) external {
        bytes32 digest = computeNounsDelegationDigest(waveSig.signer, waveSig.delegateId, waveSig.expiry);
        (address recovered, ECDSA.RecoverError err) = ECDSA.tryRecover(digest, waveSig.signature);
        if (recovered != waveSig.signer || err != ECDSA.RecoverError.NoError) revert InvalidSignature();

        uint256 votesToDelegate = nounsToken.votesToDelegate(waveSig.signer);
        uint256 votingPower = waveSig.numNouns;
        if (votesToDelegate < votingPower || votesToDelegate == 0) revert InsufficientVotingPower(waveSig.signer);

        uint256 minRequiredVotes = getCurrentMinRequiredVotes();
        if (votingPower > minRequiredVotes) votingPower = minRequiredVotes;

        Delegation memory delegation =
            Delegation(waveSig.signer, uint32(block.number), uint16(votingPower), uint16(waveSig.delegateId));
        // emits `DelegationRegistered` event
        _setOptimisticDelegation(delegation);

        address delegate;
        if (waveSig.delegateId == _nextDelegateId) {
            delegate = createDelegate();
        } else {
            delegate = getDelegateAddress(waveSig.delegateId);
        }

        // filter outdated signatures to prevent excess delegation- will require new signature
        if (nounsToken.getCurrentVotes(delegate) >= minRequiredVotes) revert DelegateSaturated(waveSig.delegateId);

        nounsToken.delegateBySig(
            delegate,
            waveSig.nonce,
            waveSig.expiry,
            uint8(bytes1(waveSig.signature[64])),
            bytes32(waveSig.signature[0:32]),
            bytes32(waveSig.signature[32:64])
        );
    }

    /// @inheritdoc IWave
    function registerDelegation(address nounder, uint256 delegateId) external {
        address delegate;
        if (delegateId == _nextDelegateId) {
            delegate = createDelegate();
        } else {
            delegate = getDelegateAddress(delegateId);
        }

        address externalDelegate = nounsToken.delegates(nounder);
        if (externalDelegate != delegate) revert NotDelegated(nounder, delegate);

        uint256 votingPower = nounsToken.votesToDelegate(nounder);
        if (votingPower == 0) revert InsufficientVotingPower(nounder);

        uint256 minRequiredVotes = getCurrentMinRequiredVotes();
        // votingPower above minimum required votes is not usable due to Nouns token implementation constraint
        if (votingPower > minRequiredVotes) votingPower = minRequiredVotes;

        Delegation memory delegation =
            Delegation(nounder, uint32(block.number), uint16(votingPower), uint16(delegateId));

        // emits `DelegationRegistered` event
        _setOptimisticDelegation(delegation);
    }

    /// @inheritdoc IWave
    function createDelegate() public returns (address delegate) {
        uint256 nextDelegateId = uint256(_nextDelegateId);
        delegate = address(new Delegate{salt: bytes32(nextDelegateId)}(address(this)));

        if (delegate == address(0x0)) revert Create2Failure();
        _nextDelegateId++;

        emit DelegateCreated(delegate, nextDelegateId);
    }

    /// @inheritdoc IWave
    function pushProposals(IWave.Proposal[] calldata winningProposals)
        public
        payable
        returns (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds)
    {
        if (msg.sender != address(ideaTokenHub)) revert Unauthorized();

        // check for external Nouns transfers or rogue redelegations, update state
        uint256[] memory disqualifiedIndices = _disqualifiedDelegationIndices();
        _deleteDelegations(disqualifiedIndices);

        // instantiate `delegations` array
        uint256 len = _optimisticDelegations.length;
        if (len == 0) revert InsufficientDelegations();
        delegations = new Delegation[](len);

        // get eligible delegates
        (, uint256[] memory eligibleProposerIds) = getAllEligibleProposerDelegates();
        // should be impossible to violate, but assert invariant in case of future changes
        assert(eligibleProposerIds.length >= winningProposals.length);

        nounsProposalIds = new uint256[](winningProposals.length);
        for (uint256 i; i < winningProposals.length; ++i) {
            // establish current proposer delegate
            uint256 currentProposerId = eligibleProposerIds[i];
            address currentProposer = getDelegateAddress(currentProposerId);

            // no event emitted to save gas since NounsGovernor already emits `ProposalCreated`
            nounsProposalIds[i] = Delegate(currentProposer).pushProposal(
                nounsGovernor, winningProposals[i].ideaTxs, winningProposals[i].description
            );
        }

        delegations = _optimisticDelegations;
    }

    /// @inheritdoc IWave
    /// @dev To the granularity of the NounsDAOProposals contract's functions, this function uses a switch case
    /// to offer options for either updating only the proposal's `ProposalTxs` struct, only the `description` string, 
    /// or both the transactions and description string simultaneously. To update only the proposal transactions,
    /// provide an empty `description` string. To update only the description, provide empty `ProposalTxs` arrays
    /// An empty string value for `updateMessage` is disallowed- all updates should be documented onchain.
    /// @notice Checks ensuring the specified proposal's updatable state will be handled by the Nouns governor
    function updatePushedProposal(
        address proposerDelegate,
        uint256 ideaId,
        uint256 nounsProposalId,
        IWave.Proposal calldata updatedProposal,
        string calldata updateMessage
    ) external {
        if (keccak256(bytes(updateMessage)) == keccak256("")) revert InvalidUpdateMessage();

        // check proposer address is a Wave delegate; reverts if no match is found
        uint256 delegateId = _findDelegateIdMatch(proposerDelegate);
        if (delegateId == 0) revert InvalidDelegateAddress(proposerDelegate);

        // check msg.sender is creator
        IIdeaTokenHub.SponsorshipParams params = ideaTokenHub.getSponsorshipInfo(msg.sender, ideaId);
        if (!params.isCreator) revert NotCreator(msg.sender);

        Delegate(proposerDelegate).updateProposal(nounsGovernor, nounsProposalId, updatedProposal.ideaTxs, updatedProposal.description, updateMessage);
    }

    // function cancelPushedProposal(address proposerDelegate, uint256 ideaId, uint256 nounsProposalId)

    /*
      Views
    */

    /// @inheritdoc IWave
    function getDelegateAddress(uint256 delegateId) public view returns (address delegate) {
        if (delegateId == 0) revert InvalidDelegateId(delegateId);
        delegate = _simulateCreate2(bytes32(uint256(delegateId)), __creationCodeHash);
    }

    /// @inheritdoc IWave
    function getDelegateId(address delegate) external view returns (uint256 delegateId) {
        delegateId = _findDelegateIdMatch(delegate);

        if (delegateId == 0) revert InvalidDelegateAddress(delegate);
    }

    /// @inheritdoc IWave
    function getDelegateIdByType(uint256 minRequiredVotes, bool isSupplementary)
        public
        view
        returns (uint256 delegateId)
    {
        delegateId = _findDelegateId(minRequiredVotes, isSupplementary);
    }

    /// @inheritdoc IWave
    function getNextDelegateId() public view returns (uint256 nextDelegateId) {
        return uint256(_nextDelegateId);
    }

    /// @inheritdoc IWave
    function getSuitableDelegateFor(address nounder)
        external
        view
        returns (address delegate, uint256 minRequiredVotes)
    {
        minRequiredVotes = getCurrentMinRequiredVotes();
        uint256 votingPower = nounsToken.votesToDelegate(nounder);
        bool isSupplementary = votingPower < minRequiredVotes ? true : false;

        uint256 delegateId = getDelegateIdByType(minRequiredVotes, isSupplementary);
        delegate = getDelegateAddress(delegateId);
    }

    /// @inheritdoc IWave
    function getCurrentMinRequiredVotes() public view returns (uint256 minRequiredVotes) {
        return nounsGovernor.proposalThreshold() + 1;
    }

    /// @inheritdoc IWave
    function getAllPartialDelegates()
        external
        view
        returns (uint256 minRequiredVotes, address[] memory partialDelegates)
    {
        minRequiredVotes = getCurrentMinRequiredVotes();
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

    /// @inheritdoc IWave
    function numEligibleProposerDelegates()
        public
        view
        returns (uint256 minRequiredVotes, uint256 numEligibleProposers)
    {
        minRequiredVotes = getCurrentMinRequiredVotes();
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
    }

    /// @inheritdoc IWave
    function getAllEligibleProposerDelegates()
        public
        view
        returns (uint256 minRequiredVotes, uint256[] memory eligibleProposerIds)
    {
        uint256 numEligibleProposers;
        (minRequiredVotes, numEligibleProposers) = numEligibleProposerDelegates();

        // populate memory array
        eligibleProposerIds = new uint256[](numEligibleProposers);
        uint256 nextDelegateId = _nextDelegateId;
        uint256 index;
        for (uint256 i = 1; i < nextDelegateId; ++i) {
            address delegateAddress = getDelegateAddress(i);
            bool noActiveProp = _checkForActiveProposal(delegateAddress);
            uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

            if (noActiveProp && currentVotes >= minRequiredVotes) {
                eligibleProposerIds[index] = i;
                index++;
            }
        }
    }

    /// @notice Delegation array in storage is optimistic and should never be relied on externally
    function getOptimisticDelegations() public view returns (Delegation[] memory) {
        return _optimisticDelegations;
    }

    /// @inheritdoc IWave
    function computeNounsDelegationDigest(address signer, uint256 delegateId, uint256 expiry)
        public
        view
        returns (bytes32 digest)
    {
        bytes32 nounsDomainTypehash = nounsToken.DOMAIN_TYPEHASH();
        string memory nounsName = nounsToken.name();
        bytes32 nounsDomainSeparator =
            keccak256(abi.encode(nounsDomainTypehash, keccak256(bytes(nounsName)), block.chainid, nounsToken));

        address delegate = getDelegateAddress(delegateId);
        uint256 signerNonce = nounsToken.nonces(signer);
        bytes32 nounsDelegationTypehash = nounsToken.DELEGATION_TYPEHASH();
        bytes32 structHash = keccak256(abi.encode(nounsDelegationTypehash, delegate, signerNonce, expiry));

        digest = ECDSA.toTypedDataHash(nounsDomainSeparator, structHash);
    }

    /*
      Internals
    */

    /// @notice Unchecked return value: returns an invalid delegate ID of `0` if no match is found. This behavior
    /// allows for non-reverting behavior but must be accounted for when invoked by higher-order functions
    function _findDelegateIdMatch(address _delegate) internal pure returns (uint256 _delegateId) {
        uint256 nextDelegateId = getNextDelegateId();
        // since 0 is an invalid delegate ID, start iterations at 1 and return `_delegateId == 0` if none is found
        for (uint256 i = 1; i <= nextDelegateId; ++i) {
            if (_simulateCreate2(bytes32(uint256(i)), __creationCodeHash) == delegate) {
                _delegateId = i;
                return;
            }
        }
    }
    
    /// @dev Returns the id of the first delegate ID found to meet the given parameters
    /// To save gas by minimizing costly SLOADs, terminates as soon as a delegate meeting the critera is found
    /// @param _minRequiredVotes The votes needed to make a proposal, dynamic based on Nouns token supply
    /// @param _isSupplementary Whether or not the returned Delegate should accept fewer than required votes
    function _findDelegateId(uint256 _minRequiredVotes, bool _isSupplementary)
        internal
        view
        returns (uint256 delegateId)
    {
        // cache in memory to reduce SLOADs
        uint256 nextDelegateId = _nextDelegateId;
        for (uint256 i = 1; i < nextDelegateId; ++i) {
            address delegateAddress = getDelegateAddress(i);
            uint256 currentVotes = nounsToken.getCurrentVotes(delegateAddress);

            // when searching for supplement delegate ID, return if additional votes are required
            if (_isSupplementary && currentVotes < _minRequiredVotes) return i;
            // when searching for solo delegate ID, return if votes are 0
            if (!_isSupplementary && currentVotes == 0) return i;
        }

        // if no delegate matching the given criteria is found, a new one must be created
        delegateId = nextDelegateId;
    }

    /// @dev Returns an array of delegation IDs that violated the protocol rules and are ineligible for yield
    function _disqualifiedDelegationIndices() internal view returns (uint256[] memory) {
        // cache _optimisticDelegations to memory to reduce SLOADs for potential event & gas optimization
        Delegation[] memory optimisticDelegations = getOptimisticDelegations();
        bool[] memory disqualifyingIndices = new bool[](optimisticDelegations.length);
        uint256 numDisqualifiedIndices;

        // search for number of disqualifications
        for (uint256 i; i < optimisticDelegations.length; ++i) {
            address nounder = optimisticDelegations[i].delegator;
            address delegate = getDelegateAddress(optimisticDelegations[i].delegateId);

            bool disqualify = _isDisqualified(nounder, delegate, optimisticDelegations[i].votingPower);

            if (disqualify == true) {
                disqualifyingIndices[i] = true;
                ++numDisqualifiedIndices;
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
            return new uint256[](0);
        }
    }

    /// @dev Returns true for delegations that violated their optimistically registered parameters
    function _isDisqualified(address _nounder, address _delegate, uint256 _votingPower)
        internal
        view
        returns (bool _disqualify)
    {
        address currentDelegate = nounsToken.delegates(_nounder);
        if (currentDelegate != _delegate) return true;
        uint256 currentBalance = nounsToken.votesToDelegate(_nounder);
        if (currentBalance < _votingPower) return true;
    }

    /// @dev Deletes Delegations by swapping the non-final index members to be removed with members to be preserved
    function _deleteDelegations(uint256[] memory _indices) internal {
        uint256[] memory sortedIndices = _sortIndicesDescending(_indices);

        for (uint256 i; i < _indices.length; ++i) {
            // will not underflow as this function is only invoked if delegation indices were found
            uint256 lastIndex = _optimisticDelegations.length - 1;
            uint256 indexToDelete = sortedIndices[i];
            Delegation memory currentDelegation = _optimisticDelegations[indexToDelete];

            if (indexToDelete != lastIndex) {
                // replace Delegation to be deleted with last member of array
                _optimisticDelegations[indexToDelete] = _optimisticDelegations[lastIndex];
            }
            _optimisticDelegations.pop();

            emit DelegationDeleted(currentDelegation);
        }
    }

    /// @dev Sorts array of indices to be deleted in descending order so the remaining indexes are not disturbed via resizing
    function _sortIndicesDescending(uint256[] memory _indices) internal pure returns (uint256[] memory) {
        for (uint256 i = 0; i < _indices.length; i++) {
            for (uint256 j = i + 1; j < _indices.length; j++) {
                if (_indices[i] < _indices[j]) {
                    // Swap
                    uint256 temp = _indices[i];
                    _indices[i] = _indices[j];
                    _indices[j] = temp;
                }
            }
        }
        return _indices;
    }

    function _setOptimisticDelegation(Delegation memory _delegation) internal {
        _optimisticDelegations.push(_delegation);

        emit DelegationRegistered(_delegation);
    }

    /// @dev Returns true when an active proposal exists for the delegate, meaning it is ineligible to propose
    function _checkForActiveProposal(address delegate) internal view returns (bool _noActiveProp) {
        uint256 delegatesLatestProposal = nounsGovernor.latestProposalIds(delegate);
        if (delegatesLatestProposal != 0) {
            _noActiveProp = _isEligibleProposalState(delegatesLatestProposal);
        } else {
            _noActiveProp = true;
        }
    }

    /// @dev References the Nouns governor contract to determine whether a proposal is in a disqualifying state
    function _isEligibleProposalState(uint256 _latestProposal) internal view returns (bool) {
        NounsDAOStorageV3.ProposalState delegatesLatestProposalState = nounsGovernor.state(_latestProposal);
        if (
            delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.ObjectionPeriod
                || delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Active
                || delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Pending
                || delegatesLatestProposalState == NounsDAOStorageV3.ProposalState.Updatable
        ) return false;

        return true;
    }

    /// @dev Computes a counterfactual Delegate address via `create2` using its creation code and `delegateId` as salt
    function _simulateCreate2(bytes32 _salt, bytes32 _creationCodeHash)
        internal
        view
        returns (address simulatedDeployment)
    {
        address factory = address(this);
        assembly {
            let ptr := mload(0x40) // instantiate free mem pointer

            // populate memory in small-Endian order to prevent `self` from overwriting the `0xff` prefix byte
            mstore(add(ptr, 0x40), _creationCodeHash) // insert 32-byte creationCodeHash at 64th offset
            mstore(add(ptr, 0x20), _salt) // insert 32-byte salt at 32nd offset
            mstore(ptr, factory) // insert 20-byte deployer address at 12th offset
            let startOffset := add(ptr, 0x0b) // prefix byte `0xff` must be inserted after `self` so it is not overwritten
            mstore8(startOffset, 0xff) // insert single byte create2 constant at 11th offset within `ptr` word

            simulatedDeployment := keccak256(startOffset, 85)
        }
    }

    function _authorizeUpgrade(address /*newImplementation*/ ) internal virtual override {
        if (msg.sender != owner()) revert Unauthorized();
    }
}
