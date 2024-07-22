# INounsDAOLogicV4
[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/interfaces/INounsDAOLogicV4.sol)

*Interface for interacting with the NounsDAOLogicV4 governor contract with minimal deployment bytecode overhead*


## Functions
### MIN_PROPOSAL_THRESHOLD_BPS

The minimum setable proposal threshold


```solidity
function MIN_PROPOSAL_THRESHOLD_BPS() external pure returns (uint256);
```

### MAX_PROPOSAL_THRESHOLD_BPS

The maximum setable proposal threshold


```solidity
function MAX_PROPOSAL_THRESHOLD_BPS() external pure returns (uint256);
```

### MIN_VOTING_PERIOD

The minimum setable voting period in blocks


```solidity
function MIN_VOTING_PERIOD() external pure returns (uint256);
```

### MAX_VOTING_PERIOD

The max setable voting period in blocks


```solidity
function MAX_VOTING_PERIOD() external pure returns (uint256);
```

### MIN_VOTING_DELAY

The min setable voting delay in blocks


```solidity
function MIN_VOTING_DELAY() external pure returns (uint256);
```

### MAX_VOTING_DELAY

The max setable voting delay in blocks


```solidity
function MAX_VOTING_DELAY() external pure returns (uint256);
```

### proposalMaxOperations

The maximum number of actions that can be included in a proposal


```solidity
function proposalMaxOperations() external pure returns (uint256);
```

### initialize

Used to initialize the contract during delegator contructor


```solidity
function initialize(
    address timelock_,
    address nouns_,
    address forkEscrow_,
    address forkDAODeployer_,
    address vetoer_,
    NounsDAOStorage.NounsDAOParams calldata daoParams_,
    NounsDAOStorage.DynamicQuorumParams calldata dynamicQuorumParams_
) external;
```

### propose

Function used to propose a new proposal. Sender must have delegates above the proposal threshold


```solidity
function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
) external returns (uint256);
```

### proposeOnTimelockV1

Function used to propose a new proposal. Sender must have delegates above the proposal threshold.
This proposal would be executed via the timelockV1 contract. This is meant to be used in case timelockV1
is still holding funds or has special permissions to execute on certain contracts.


```solidity
function proposeOnTimelockV1(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
) external returns (uint256);
```

### proposeBySigs

Function used to propose a new proposal. Sender and signers must have delegates above the proposal threshold
Signers are regarded as co-proposers, and therefore have the ability to cancel the proposal at any time.


```solidity
function proposeBySigs(
    NounsDAOStorage.ProposerSignature[] memory proposerSignatures,
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
) external returns (uint256);
```

### cancelSig

Invalidates a signature that may be used for signing a new proposal.


```solidity
function cancelSig(bytes calldata sig) external;
```

### updateProposal

Update a proposal transactions and description.
Only the proposer can update it, and only during the updateable period.


```solidity
function updateProposal(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description,
    string memory updateMessage
) external;
```

### updateProposalDescription

Updates the proposal's description. Only the proposer can update it, and only during the updateable period.


```solidity
function updateProposalDescription(uint256 proposalId, string calldata description, string calldata updateMessage)
    external;
```

### updateProposalTransactions

Updates the proposal's transactions. Only the proposer can update it, and only during the updateable period.


```solidity
function updateProposalTransactions(
    uint256 proposalId,
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory updateMessage
) external;
```

### updateProposalBySigs

Update a proposal's transactions and description that was created with proposeBySigs.


```solidity
function updateProposalBySigs(
    uint256 proposalId,
    NounsDAOStorage.ProposerSignature[] memory proposerSignatures,
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description,
    string memory updateMessage
) external;
```

### queue

Queues a proposal of state succeeded


```solidity
function queue(uint256 proposalId) external;
```

### execute

Executes a queued proposal if eta has passed


```solidity
function execute(uint256 proposalId) external;
```

### executeOnTimelockV1

Executes a queued proposal on timelockV1 if eta has passed


```solidity
function executeOnTimelockV1(uint256 proposalId) external;
```

### cancel

Cancels a proposal only if sender is the proposer or a signer, or proposer & signers voting power
dropped below proposal threshold


```solidity
function cancel(uint256 proposalId) external;
```

### state

Gets the state of a proposal


```solidity
function state(uint256 proposalId) external view returns (NounsDAOTypes.ProposalState);
```

### getActions

Gets actions of a proposal


```solidity
function getActions(uint256 proposalId)
    external
    view
    returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas);
```

### getReceipt

Gets the receipt for a voter on a given proposal


```solidity
function getReceipt(uint256 proposalId, address voter) external view returns (NounsDAOStorage.Receipt memory);
```

### proposals

Returns the proposal details given a proposal id.


```solidity
function proposals(uint256 proposalId) external view returns (NounsDAOTypes.ProposalCondensedV3 memory);
```

### proposalsV3

Returns the proposal details given a proposal id.


```solidity
function proposalsV3(uint256 proposalId) external view returns (NounsDAOTypes.ProposalCondensedV3 memory);
```

### proposalThreshold

Current proposal threshold using Noun Total Supply


```solidity
function proposalThreshold() external view returns (uint256);
```

### escrowToFork

Escrow Nouns to contribute to the fork threshold


```solidity
function escrowToFork(uint256[] calldata tokenIds, uint256[] calldata proposalIds, string calldata reason) external;
```

### withdrawFromForkEscrow

Withdraw Nouns from the fork escrow. Only possible if the fork has not been executed.


```solidity
function withdrawFromForkEscrow(uint256[] calldata tokenIds) external;
```

### executeFork

Execute the fork. Only possible if the fork threshold has been met.


```solidity
function executeFork() external returns (address forkTreasury, address forkToken);
```

### joinFork

Joins a fork while a fork is active


```solidity
function joinFork(uint256[] calldata tokenIds, uint256[] calldata proposalIds, string calldata reason) external;
```

### withdrawDAONounsFromEscrowToTreasury

Withdraws nouns from the fork escrow to the treasury after the fork has been executed


```solidity
function withdrawDAONounsFromEscrowToTreasury(uint256[] calldata tokenIds) external;
```

### withdrawDAONounsFromEscrowIncreasingTotalSupply

Withdraws nouns from the fork escrow after the fork has been executed to an address other than the treasury


```solidity
function withdrawDAONounsFromEscrowIncreasingTotalSupply(uint256[] calldata tokenIds, address to) external;
```

### adjustedTotalSupply

Returns the number of nouns in supply minus nouns owned by the DAO, i.e. held in the treasury or in an
escrow after it has closed.


```solidity
function adjustedTotalSupply() external view returns (uint256);
```

### forkThreshold

returns the required number of tokens to escrow to trigger a fork


```solidity
function forkThreshold() external view returns (uint256);
```

### numTokensInForkEscrow

Returns the number of tokens currently in escrow, contributing to the fork threshold


```solidity
function numTokensInForkEscrow() external view returns (uint256);
```

### veto

Vetoes a proposal only if sender is the vetoer and the proposal has not been executed.


```solidity
function veto(uint256 proposalId) external;
```

### castVote

Cast a vote for a proposal


```solidity
function castVote(uint256 proposalId, uint8 support) external;
```

### castRefundableVote

Cast a vote for a proposal, asking the DAO to refund gas costs.


```solidity
function castRefundableVote(uint256 proposalId, uint8 support) external;
```

### castRefundableVoteWithReason

Cast a vote for a proposal, asking the DAO to refund gas costs.


```solidity
function castRefundableVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external;
```

### castVoteWithReason

Cast a vote for a proposal with a reason


```solidity
function castVoteWithReason(uint256 proposalId, uint8 support, string calldata reason) external;
```

### castVoteBySig

Cast a vote for a proposal by signature


```solidity
function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external;
```

### _setVotingDelay

Admin function for setting the voting delay. Best to set voting delay to at least a few days, to give
voters time to make sense of proposals, e.g. 21,600 blocks which should be at least 3 days.


```solidity
function _setVotingDelay(uint256 newVotingDelay) external;
```

### _setVotingPeriod

Admin function for setting the voting period


```solidity
function _setVotingPeriod(uint256 newVotingPeriod) external;
```

### _setProposalThresholdBPS

Admin function for setting the proposal threshold basis points


```solidity
function _setProposalThresholdBPS(uint256 newProposalThresholdBPS) external;
```

### _setObjectionPeriodDurationInBlocks

Admin function for setting the objection period duration


```solidity
function _setObjectionPeriodDurationInBlocks(uint32 newObjectionPeriodDurationInBlocks) external;
```

### _setLastMinuteWindowInBlocks

Admin function for setting the objection period last minute window


```solidity
function _setLastMinuteWindowInBlocks(uint32 newLastMinuteWindowInBlocks) external;
```

### _setProposalUpdatablePeriodInBlocks

Admin function for setting the proposal updatable period


```solidity
function _setProposalUpdatablePeriodInBlocks(uint32 newProposalUpdatablePeriodInBlocks) external;
```

### _setPendingAdmin

Begins transfer of admin rights. The newPendingAdmin must call `_acceptAdmin` to finalize the transfer.


```solidity
function _setPendingAdmin(address newPendingAdmin) external;
```

### _acceptAdmin

Accepts transfer of admin rights. msg.sender must be pendingAdmin


```solidity
function _acceptAdmin() external;
```

### _setPendingVetoer

Begins transition of vetoer. The newPendingVetoer must call _acceptVetoer to finalize the transfer.


```solidity
function _setPendingVetoer(address newPendingVetoer) external;
```

### _acceptVetoer

Called by the pendingVetoer to accept role and update vetoer


```solidity
function _acceptVetoer() external;
```

### _burnVetoPower

Burns veto priviledges


```solidity
function _burnVetoPower() external;
```

### _setMinQuorumVotesBPS

Admin function for setting the minimum quorum votes bps


```solidity
function _setMinQuorumVotesBPS(uint16 newMinQuorumVotesBPS) external;
```

### _setMaxQuorumVotesBPS

Admin function for setting the maximum quorum votes bps


```solidity
function _setMaxQuorumVotesBPS(uint16 newMaxQuorumVotesBPS) external;
```

### _setQuorumCoefficient

Admin function for setting the dynamic quorum coefficient


```solidity
function _setQuorumCoefficient(uint32 newQuorumCoefficient) external;
```

### _setDynamicQuorumParams

Admin function for setting all the dynamic quorum parameters


```solidity
function _setDynamicQuorumParams(uint16 newMinQuorumVotesBPS, uint16 newMaxQuorumVotesBPS, uint32 newQuorumCoefficient)
    external;
```

### _withdraw

Withdraws all the ETH in the contract. This is callable only by the admin (timelock)


```solidity
function _withdraw() external returns (uint256, bool);
```

### _setForkPeriod

Admin function for setting the fork period


```solidity
function _setForkPeriod(uint256 newForkPeriod) external;
```

### _setForkThresholdBPS

Admin function for setting the fork threshold


```solidity
function _setForkThresholdBPS(uint256 newForkThresholdBPS) external;
```

### _setVoteSnapshotBlockSwitchProposalId

Admin function for setting the proposal id at which vote snapshots start using the voting start block
instead of the proposal creation block.


```solidity
function _setVoteSnapshotBlockSwitchProposalId() external;
```

### _setForkDAODeployer

Admin function for setting the fork DAO deployer contract


```solidity
function _setForkDAODeployer(address newForkDAODeployer) external;
```

### _setErc20TokensToIncludeInFork

Admin function for setting the ERC20 tokens that are used when splitting funds to a fork


```solidity
function _setErc20TokensToIncludeInFork(address[] calldata erc20tokens) external;
```

### _setForkEscrow

Admin function for setting the fork escrow contract


```solidity
function _setForkEscrow(address newForkEscrow) external;
```

### _setForkParams

Admin function for setting the fork related parameters


```solidity
function _setForkParams(
    address forkEscrow_,
    address forkDAODeployer_,
    address[] calldata erc20TokensToIncludeInFork_,
    uint256 forkPeriod_,
    uint256 forkThresholdBPS_
) external;
```

### _setTimelocksAndAdmin

Admin function for setting the timelocks and admin


```solidity
function _setTimelocksAndAdmin(address newTimelock, address newTimelockV1, address newAdmin) external;
```

### quorumVotes

Quorum votes required for a specific proposal to succeed


```solidity
function quorumVotes(uint256 proposalId) external view returns (uint256);
```

### dynamicQuorumVotes

Calculates the required quorum of for-votes based on the amount of against-votes


```solidity
function dynamicQuorumVotes(
    uint256 againstVotes,
    uint256 adjustedTotalSupply_,
    NounsDAOStorage.DynamicQuorumParams memory params
) external pure returns (uint256);
```

### getDynamicQuorumParamsAt

returns the dynamic quorum parameters values at a certain block number


```solidity
function getDynamicQuorumParamsAt(uint256 blockNumber_)
    external
    view
    returns (NounsDAOStorage.DynamicQuorumParams memory);
```

### minQuorumVotes

Current min quorum votes using Nouns adjusted total supply


```solidity
function minQuorumVotes() external view returns (uint256);
```

### maxQuorumVotes

Current max quorum votes using Nouns adjusted total supply


```solidity
function maxQuorumVotes() external view returns (uint256);
```

### quorumParamsCheckpoints

Get all quorum params checkpoints


```solidity
function quorumParamsCheckpoints() external view returns (NounsDAOStorage.DynamicQuorumParamsCheckpoint[] memory);
```

### quorumParamsCheckpoints

Get a quorum params checkpoint by its index


```solidity
function quorumParamsCheckpoints(uint256 index)
    external
    view
    returns (NounsDAOStorage.DynamicQuorumParamsCheckpoint memory);
```

### vetoer


```solidity
function vetoer() external view returns (address);
```

### pendingVetoer


```solidity
function pendingVetoer() external view returns (address);
```

### votingDelay


```solidity
function votingDelay() external view returns (uint256);
```

### votingPeriod


```solidity
function votingPeriod() external view returns (uint256);
```

### proposalThresholdBPS


```solidity
function proposalThresholdBPS() external view returns (uint256);
```

### quorumVotesBPS


```solidity
function quorumVotesBPS() external view returns (uint256);
```

### proposalCount


```solidity
function proposalCount() external view returns (uint256);
```

### timelock


```solidity
function timelock() external view returns (INounsDAOExecutor);
```

### nouns


```solidity
function nouns() external view returns (NounsTokenLike);
```

### latestProposalIds


```solidity
function latestProposalIds(address account) external view returns (uint256);
```

### lastMinuteWindowInBlocks


```solidity
function lastMinuteWindowInBlocks() external view returns (uint256);
```

### objectionPeriodDurationInBlocks


```solidity
function objectionPeriodDurationInBlocks() external view returns (uint256);
```

### erc20TokensToIncludeInFork


```solidity
function erc20TokensToIncludeInFork() external view returns (address[] memory);
```

### forkEscrow


```solidity
function forkEscrow() external view returns (INounsDAOForkEscrow);
```

### forkDAODeployer


```solidity
function forkDAODeployer() external view returns (IForkDAODeployer);
```

### forkEndTimestamp


```solidity
function forkEndTimestamp() external view returns (uint256);
```

### forkPeriod


```solidity
function forkPeriod() external view returns (uint256);
```

### forkThresholdBPS


```solidity
function forkThresholdBPS() external view returns (uint256);
```

### proposalUpdatablePeriodInBlocks


```solidity
function proposalUpdatablePeriodInBlocks() external view returns (uint256);
```

### timelockV1


```solidity
function timelockV1() external view returns (address);
```

### voteSnapshotBlockSwitchProposalId


```solidity
function voteSnapshotBlockSwitchProposalId() external view returns (uint256);
```

