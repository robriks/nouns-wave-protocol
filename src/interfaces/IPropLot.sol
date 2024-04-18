// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {NounsDAOV3Proposals} from "nouns-monorepo/governance/NounsDAOV3Proposals.sol";

/// @dev Interface for interacting with the PropLot protocol core contract
interface IPropLot {
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
        uint16 votingPower;
        uint16 delegateId;
    }

    struct PropLotSignature {
        address signer;
        uint256 delegateId;
        uint256 numNouns;
        uint256 nonce;
        uint256 expiry;
        bytes signature;
    }

    struct Proposal {
        NounsDAOV3Proposals.ProposalTxs ideaTxs;
        string description;
    }

    /*
      Errors + Events
    */

    error Unauthorized();
    error InsufficientDelegations();
    error NotDelegated(address nounder, address delegate);
    error InsufficientVotingPower(address nounder);
    error DelegateSaturated(uint256 delegateId);
    error InvalidDelegateId(uint256 delegateId);
    error InvalidSignature();
    error OnlyDelegatecallContext();
    error Create2Failure();

    event DelegateCreated(address delegate, uint256 id);
    event DelegationRegistered(Delegation optimisticDelegation);
    event DelegationDeleted(Delegation disqualifiedDelegation);

    /*
      IPropLot
    */

    function initialize(address ideaTokenHub_, address nounsGovernor_, address nounsToken_, string memory uri) external;

    /// @dev Pushes the winning proposal onto the `nounsGovernor` to be voted on in the Nouns governance ecosystem
    /// Checks for changes in delegation state on `nounsToken` contract and updates PropLot recordkeeping accordingly
    /// @notice May only be called by the PropLot's ERC1155 Idea token hub at the conclusion of each 2-week wave
    function pushProposals(Proposal[] calldata winningProposals)
        external
        payable
        returns (Delegation[] memory delegations, uint256[] memory nounsProposalIds);

    /// @dev Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
    /// in a single function call. This is the most convenient option for standard wallets using EOA private keys
    /// @notice The Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures and thus
    /// does not support smart contract signatures. In that case, `delegate()` must be called on the Nouns contract directly
    function delegateBySig(PropLotSignature calldata propLotSig) external;

    /// @dev Updates this contract's storage to reflect delegations performed directly on the Nouns token contract
    /// @dev Serves as an alternative to `delegateByDelegatecall()` for smart contract wallets
    /// @notice Delegation to must have been performed via a call to the Nouns token contract using either the
    /// `delegate()` or `delegateBySig()` function, having provided the correct Delegate address for the given ID
    function registerDelegation(address nounder, uint256 delegateId) external;

    /// @dev Deploys a Delegate contract deterministically via `create2`, using the `_nextDelegateId` as salt
    /// @notice As the constructor argument is appended to bytecode, it affects resulting address, eliminating risk of DOS vector
    function createDelegate() external returns (address delegate);

    /// @dev Computes the counterfactual address for a given delegate ID whether or not it has been deployed
    function getDelegateAddress(uint256 delegateId) external view returns (address delegate);

    /// @dev Returns either an existing delegate ID if one meets the given parameters, otherwise returns the next delegate ID
    /// @param isSupplementary Whether or not to search for a Delegate that doesn't meet the current proposal threshold
    /// @param minRequiredVotes Minimum votes to make a proposal. Must be more than current proposal threshold which is based on Nouns token supply
    /// @return delegateId The ID of a delegate that matches the given criteria
    function getDelegateIdByType(uint256 minRequiredVotes, bool isSupplementary)
        external
        view
        returns (uint256 delegateId);

    /// @dev Typecasts and returns the next delegate ID as a `uint256`
    function getNextDelegateId() external view returns (uint256 nextDelegateId);

    /// @dev Returns a suitable delegate address for an account based on its voting power
    function getSuitableDelegateFor(address nounder)
        external
        view
        returns (address delegate, uint256 minRequiredVotes);

    /// @dev Returns the current minimum votes required to submit an onchain proposal to Nouns governance
    function getCurrentMinRequiredVotes() external view returns (uint256 minRequiredVotes);

    /// @dev Returns all existing Delegates with voting power below the minimum required to make a proposal
    /// Provided to improve offchain devX; returned values can change at any time as Nouns ecosystem is external
    function getAllPartialDelegates()
        external
        view
        returns (uint256 minRequiredVotes, address[] memory partialDelegates);

    /// @dev Returns the number of existing Delegates currently eligible to make a proposal
    function numEligibleProposerDelegates()
        external
        view
        returns (uint256 minRequiredVotes, uint256 numEligibleProposers);

    /// @dev Returns all existing Delegates currently eligible for making a proposal
    /// Provided to improve offchain devX: returned values can change at any time as Nouns ecosystem is external
    function getAllEligibleProposerDelegates()
        external
        view
        returns (uint256 minRequiredVotes, uint256[] memory eligibleProposerIds);

    /// @dev Returns optimistic delegations from storage. These are subject to change and should never be relied upon
    function getOptimisticDelegations() external view returns (Delegation[] memory);
    
    /// @dev Convenience function to facilitate offchain development by computing the `delegateBySig()` digest
    /// for a given signer and expiry
    function computeNounsDelegationDigest(address signer, uint256 delegateId, uint256 expiry)
        external
        view
        returns (bytes32 digest);
}
