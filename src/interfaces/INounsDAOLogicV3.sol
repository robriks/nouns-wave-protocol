// SPDX-License-Identifier: BSD-3-Clause

/// @dev Interface for interacting with the NounsDAOLogicV3 governor contract with minimal deployment bytecode overhead
pragma solidity ^0.8.24;

import {
    NounsDAOStorageV3, 
    NounsDAOStorageV2, 
    INounsDAOExecutor, 
    NounsTokenLike,
    INounsDAOForkEscrow,
    IForkDAODeployer
} from "nouns-monorepo/governance/NounsDAOInterfaces.sol";

interface INounsDAOLogicV3 {

    /// @notice The minimum setable proposal threshold
    function MIN_PROPOSAL_THRESHOLD_BPS() external pure returns (uint256);
    /// @notice The maximum setable proposal threshold
    function MAX_PROPOSAL_THRESHOLD_BPS() external pure returns (uint256);
    /// @notice The minimum setable voting period in blocks
    function MIN_VOTING_PERIOD() external pure returns (uint256);
    /// @notice The max setable voting period in blocks
    function MAX_VOTING_PERIOD() external pure returns (uint256);
    /// @notice The min setable voting delay in blocks
    function MIN_VOTING_DELAY() external pure returns (uint256);
    /// @notice The max setable voting delay in blocks
    function MAX_VOTING_DELAY() external pure returns (uint256);
    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() external pure returns (uint256);

    /// @notice Used to initialize the contract during delegator contructor
    function initialize(
        address timelock_,
        address nouns_,
        address forkEscrow_,
        address forkDAODeployer_,
        address vetoer_,
        NounsDAOStorageV3.NounsDAOParams calldata daoParams_,
        NounsDAOStorageV3.DynamicQuorumParams calldata dynamicQuorumParams_
    ) external;

    /// @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold
    function propose(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    /// @notice Function used to propose a new proposal. Sender must have delegates above the proposal threshold.
    /// This proposal would be executed via the timelockV1 contract. This is meant to be used in case timelockV1
    /// is still holding funds or has special permissions to execute on certain contracts.
    function proposeOnTimelockV1(
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    /// @notice Function used to propose a new proposal. Sender and signers must have delegates above the proposal threshold
    /// Signers are regarded as co-proposers, and therefore have the ability to cancel the proposal at any time.
    function proposeBySigs(
        NounsDAOStorageV3.ProposerSignature[] memory proposerSignatures,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint256);

    /// @notice Invalidates a signature that may be used for signing a new proposal.
    function cancelSig(bytes calldata sig) external;

    /// @notice Update a proposal transactions and description.
    /// Only the proposer can update it, and only during the updateable period.
    function updateProposal(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description,
        string memory updateMessage
    ) external;

    /// @notice Updates the proposal's description. Only the proposer can update it, and only during the updateable period.
    function updateProposalDescription(
        uint256 proposalId,
        string calldata description,
        string calldata updateMessage
    ) external;

    /// @notice Updates the proposal's transactions. Only the proposer can update it, and only during the updateable period.
    function updateProposalTransactions(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory updateMessage
    ) external;

    /// @notice Update a proposal's transactions and description that was created with proposeBySigs.
    function updateProposalBySigs(
        uint256 proposalId,
        NounsDAOStorageV3.ProposerSignature[] memory proposerSignatures,
        address[] memory targets,
        uint256[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description,
        string memory updateMessage
    ) external;

    /// @notice Queues a proposal of state succeeded
    function queue(uint256 proposalId) external;
    /// @notice Executes a queued proposal if eta has passed
    function execute(uint256 proposalId) external;
    /// @notice Executes a queued proposal on timelockV1 if eta has passed
    function executeOnTimelockV1(uint256 proposalId) external;
    /// @notice Cancels a proposal only if sender is the proposer or a signer, or proposer & signers voting power
    /// dropped below proposal threshold
    function cancel(uint256 proposalId) external;
    /// @notice Gets the state of a proposal
    function state(uint256 proposalId) external view returns (NounsDAOStorageV3.ProposalState);
    /// @notice Gets actions of a proposal
    
    function getActions(uint256 proposalId)
        external
        view
        returns (
            address[] memory targets,
            uint256[] memory values,
            string[] memory signatures,
            bytes[] memory calldatas
        );

    /// @notice Gets the receipt for a voter on a given proposal
    function getReceipt(uint256 proposalId, address voter) external view returns (NounsDAOStorageV3.Receipt memory);
    /// @notice Returns the proposal details given a proposal id.
    function proposals(uint256 proposalId) external view returns (NounsDAOStorageV2.ProposalCondensed memory);
    /// @notice Returns the proposal details given a proposal id.
    function proposalsV3(uint256 proposalId) external view returns (NounsDAOStorageV3.ProposalCondensed memory);
    /// @notice Current proposal threshold using Noun Total Supply
    function proposalThreshold() external view returns (uint256);
    
    /// @notice Escrow Nouns to contribute to the fork threshold
    function escrowToFork(
        uint256[] calldata tokenIds,
        uint256[] calldata proposalIds,
        string calldata reason
    ) external;

    /// @notice Withdraw Nouns from the fork escrow. Only possible if the fork has not been executed.
    function withdrawFromForkEscrow(uint256[] calldata tokenIds) external;
    /// @notice Execute the fork. Only possible if the fork threshold has been met.
    function executeFork() external returns (address forkTreasury, address forkToken);

    /// @notice Joins a fork while a fork is active
    function joinFork(
        uint256[] calldata tokenIds,
        uint256[] calldata proposalIds,
        string calldata reason
    ) external;

    /// @notice Withdraws nouns from the fork escrow to the treasury after the fork has been executed
    function withdrawDAONounsFromEscrowToTreasury(uint256[] calldata tokenIds) external;
    /// @notice Withdraws nouns from the fork escrow after the fork has been executed to an address other than the treasury
    function withdrawDAONounsFromEscrowIncreasingTotalSupply(uint256[] calldata tokenIds, address to) external;
    /// @notice Returns the number of nouns in supply minus nouns owned by the DAO, i.e. held in the treasury or in an
    /// escrow after it has closed.
    function adjustedTotalSupply() external view returns (uint256);
    /// @notice returns the required number of tokens to escrow to trigger a fork
    function forkThreshold() external view returns (uint256);
    /// @notice Returns the number of tokens currently in escrow, contributing to the fork threshold
    function numTokensInForkEscrow() external view returns (uint256);
    /// @notice Vetoes a proposal only if sender is the vetoer and the proposal has not been executed.
    function veto(uint256 proposalId) external;
    /// @notice Cast a vote for a proposal
    function castVote(uint256 proposalId, uint8 support) external;
    /// @notice Cast a vote for a proposal, asking the DAO to refund gas costs.
    function castRefundableVote(uint256 proposalId, uint8 support) external;
    
    /// @notice Cast a vote for a proposal, asking the DAO to refund gas costs.
    function castRefundableVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external;
    
    /// @notice Cast a vote for a proposal with a reason
    function castVoteWithReason(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external;

    /// @notice Cast a vote for a proposal by signature
    function castVoteBySig(
        uint256 proposalId,
        uint8 support,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @notice Admin function for setting the voting delay. Best to set voting delay to at least a few days, to give
    /// voters time to make sense of proposals, e.g. 21,600 blocks which should be at least 3 days.
    function _setVotingDelay(uint256 newVotingDelay) external;
    /// @notice Admin function for setting the voting period
    function _setVotingPeriod(uint256 newVotingPeriod) external;
    /// @notice Admin function for setting the proposal threshold basis points
    function _setProposalThresholdBPS(uint256 newProposalThresholdBPS) external;
    /// @notice Admin function for setting the objection period duration

    function _setObjectionPeriodDurationInBlocks(uint32 newObjectionPeriodDurationInBlocks) external;

    /// @notice Admin function for setting the objection period last minute window
    function _setLastMinuteWindowInBlocks(uint32 newLastMinuteWindowInBlocks) external;
    /// @notice Admin function for setting the proposal updatable period
    function _setProposalUpdatablePeriodInBlocks(uint32 newProposalUpdatablePeriodInBlocks) external;
    /// @notice Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.
    function _setPendingAdmin(address newPendingAdmin) external;
    /// @notice Accepts transfer of admin rights. msg.sender must be pendingAdmin
    function _acceptAdmin() external;
    /// @notice Begins transition of vetoer. The newPendingVetoer must call _acceptVetoer to finalize the transfer.
    function _setPendingVetoer(address newPendingVetoer) external;
    /// @notice Called by the pendingVetoer to accept role and update vetoer
    function _acceptVetoer() external;
    /// @notice Burns veto priviledges
    function _burnVetoPower() external;
    /// @notice Admin function for setting the minimum quorum votes bps
    function _setMinQuorumVotesBPS(uint16 newMinQuorumVotesBPS) external;
    /// @notice Admin function for setting the maximum quorum votes bps
    function _setMaxQuorumVotesBPS(uint16 newMaxQuorumVotesBPS) external;
    /// @notice Admin function for setting the dynamic quorum coefficient
    function _setQuorumCoefficient(uint32 newQuorumCoefficient) external;
    /// @notice Admin function for setting all the dynamic quorum parameters
    function _setDynamicQuorumParams(
        uint16 newMinQuorumVotesBPS,
        uint16 newMaxQuorumVotesBPS,
        uint32 newQuorumCoefficient
    ) external;

    /// @notice Withdraws all the ETH in the contract. This is callable only by the admin (timelock)
    function _withdraw() external returns (uint256, bool);
    /// @notice Admin function for setting the fork period
    function _setForkPeriod(uint256 newForkPeriod) external;
    /// @notice Admin function for setting the fork threshold
    function _setForkThresholdBPS(uint256 newForkThresholdBPS) external;
    /// @notice Admin function for setting the proposal id at which vote snapshots start using the voting start block
    /// instead of the proposal creation block.
    function _setVoteSnapshotBlockSwitchProposalId() external;
    /// @notice Admin function for setting the fork DAO deployer contract
    function _setForkDAODeployer(address newForkDAODeployer) external;
    /// @notice Admin function for setting the ERC20 tokens that are used when splitting funds to a fork
    function _setErc20TokensToIncludeInFork(address[] calldata erc20tokens) external;
    /// @notice Admin function for setting the fork escrow contract
    function _setForkEscrow(address newForkEscrow) external;

    /// @notice Admin function for setting the fork related parameters
    function _setForkParams(
        address forkEscrow_,
        address forkDAODeployer_,
        address[] calldata erc20TokensToIncludeInFork_,
        uint256 forkPeriod_,
        uint256 forkThresholdBPS_
    ) external;

    /// @notice Admin function for setting the timelocks and admin
    function _setTimelocksAndAdmin(
        address newTimelock,
        address newTimelockV1,
        address newAdmin
    ) external;

    /// @notice Quorum votes required for a specific proposal to succeed
    function quorumVotes(uint256 proposalId) external view returns (uint256);

    /// @notice Calculates the required quorum of for-votes based on the amount of against-votes
    function dynamicQuorumVotes(
        uint256 againstVotes,
        uint256 adjustedTotalSupply_,
        NounsDAOStorageV3.DynamicQuorumParams memory params
    ) external pure returns (uint256);

    /// @notice returns the dynamic quorum parameters values at a certain block number
    function getDynamicQuorumParamsAt(uint256 blockNumber_) external view returns (NounsDAOStorageV3.DynamicQuorumParams memory);
    /// @notice Current min quorum votes using Nouns adjusted total supply
    function minQuorumVotes() external view returns (uint256);
    /// @notice Current max quorum votes using Nouns adjusted total supply
    function maxQuorumVotes() external view returns (uint256);
    /// @notice Get all quorum params checkpoints
    function quorumParamsCheckpoints() external view returns (NounsDAOStorageV3.DynamicQuorumParamsCheckpoint[] memory);
    /// @notice Get a quorum params checkpoint by its index
    function quorumParamsCheckpoints(uint256 index) external view returns (NounsDAOStorageV3.DynamicQuorumParamsCheckpoint memory);
    function vetoer() external view returns (address);
    function pendingVetoer() external view returns (address);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function proposalThresholdBPS() external view returns (uint256);
    function quorumVotesBPS() external view returns (uint256);
    function proposalCount() external view returns (uint256);
    function timelock() external view returns (INounsDAOExecutor);
    function nouns() external view returns (NounsTokenLike);
    function latestProposalIds(address account) external view returns (uint256);
    function lastMinuteWindowInBlocks() external view returns (uint256);
    function objectionPeriodDurationInBlocks() external view returns (uint256);
    function erc20TokensToIncludeInFork() external view returns (address[] memory);
    function forkEscrow() external view returns (INounsDAOForkEscrow);
    function forkDAODeployer() external view returns (IForkDAODeployer);
    function forkEndTimestamp() external view returns (uint256);
    function forkPeriod() external view returns (uint256);
    function forkThresholdBPS() external view returns (uint256);
    function proposalUpdatablePeriodInBlocks() external view returns (uint256);
    function timelockV1() external view returns (address);
    function voteSnapshotBlockSwitchProposalId() external view returns (uint256);
}
