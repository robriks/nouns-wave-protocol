# IdeaTokenHub

[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/IdeaTokenHub.sol)

**Inherits:**
OwnableUpgradeable, UUPSUpgradeable, ERC1155Upgradeable, [IIdeaTokenHub](/src/interfaces/IIdeaTokenHub.sol/interface.IIdeaTokenHub.md)

**Author:**
📯📯📯.eth

## State Variables

### decimals

```solidity
uint256 public constant decimals = 18;
```

### \_\_waveCore

```solidity
IWave private __waveCore;
```

### \_\_nounsGovernor

```solidity
INounsDAOLogicV3 private __nounsGovernor;
```

### minSponsorshipAmount

_ERC1155 balance recordkeeping directly mirrors Ether values_

```solidity
uint256 public minSponsorshipAmount;
```

### waveLength

_The length of time for a wave in blocks, marking the block number where winning ideas are chosen_

```solidity
uint256 public waveLength;
```

### \_currentWaveId

```solidity
uint256 private _currentWaveId;
```

### \_nextIdeaId

```solidity
uint96 private _nextIdeaId;
```

### ideaInfos

`type(uint96).max` size provides a large buffer for tokenIds, overflow is unrealistic

```solidity
mapping(uint96 => IdeaInfo) internal ideaInfos;
```

### waveInfos

```solidity
mapping(uint256 => WaveInfo) internal waveInfos;
```

### sponsorships

```solidity
mapping(address => mapping(uint96 => SponsorshipParams)) internal sponsorships;
```

### claimableYield

```solidity
mapping(address => uint256) internal claimableYield;
```

## Functions

### constructor

```solidity
constructor();
```

### initialize

```solidity
function initialize(
    address owner_,
    address nounsGovernor_,
    uint256 minSponsorshipAmount_,
    uint256 waveLength_,
    string memory uri_
) external virtual initializer;
```

### createIdea

To combat spam and low-quality proposals, idea token creation requires a small minimum payment
The Ether amount paid to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio

_Creates a new ERC1155 token referred to by its token ID, ie its `ideaId` identifier_

```solidity
function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description)
    public
    payable
    returns (uint96 newIdeaId);
```

### sponsorIdea

To incentivize smooth protocol transitions and continued rollover of auction waves,
sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed

_Sponsors the existing ERC1155 tokenized idea specified by its ID. The Ether amount paid
to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio_

```solidity
function sponsorIdea(uint96 ideaId) public payable;
```

### sponsorIdeaWithReason

To incentivize smooth protocol transitions and continued rollover of auction waves,
sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed

_Idential execution to `sponsorIdea()` emitting a separate event with additional description string_

```solidity
function sponsorIdeaWithReason(uint96 ideaId, string calldata reason) public payable;
```

### finalizeWave

To save gas on `description` string SSTOREs, descriptions are stored offchain and their winning IDs must be re-validated in memory

_Finalizes a Wave wave, marking the end of an auction wave. Winning ideas are selected by the highest
sponsored balances and officially proposed to the Nouns governance contracts. The number of winners varies
depending on the available 'liquidity' of lent Nouns NFTs and their proposal power. Yield distributions are
tallied by calling the Wave Core and recording valid delegations in the `claimableYield` mapping where they
can then be claimed at any time by a Nouns holder who has delegated to Wave_

```solidity
function finalizeWave(uint96[] calldata offchainWinningIds, string[] calldata offchainDescriptions)
    external
    returns (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds);
```

### claim

Reentrance prevented via CEI

_Provides a way to collect the yield earned by Nounders who have delegated to Wave for a full wave_

```solidity
function claim() external returns (uint256 claimAmt);
```

### setMinSponsorshipAmount

Only callable by the owner

_Sets the new minimum funding required to create and sponsor tokenized ideas_

```solidity
function setMinSponsorshipAmount(uint256 newMinSponsorshipAmount) external onlyOwner;
```

### setWaveLength

Only callable by the owner

_Sets the new length of Wave waves in blocks_

```solidity
function setWaveLength(uint256 newWavelength) external onlyOwner;
```

### getWinningIdeaIds

Intended for offchain usage to aid in fetching offchain `description` string data before calling `finalizeWave()`
If a full list of eligible IdeaIds ordered by current funding is desired, use `getOrderedEligibleIdeaIds(0)` instead

_Returns an array of the current wave's leading IdeaIds where the array length is determined
by the protocol's number of available proposer delegates, fetched from the WaveCore contract_

```solidity
function getWinningIdeaIds()
    public
    view
    returns (uint256 minRequiredVotes, uint256 numEligibleProposers, uint96[] memory winningIds);
```

### getOrderedEligibleIdeaIds

The returned array treats ineligible IDs (ie already proposed) as 0 values at the array end.
Since 0 is an invalid `ideaId`, these are filtered out when invoked by `finalizeWave()` and `getWinningIdeaIds()`

_Fetches an array of `ideaIds` eligible for proposal, ordered by total funding_

```solidity
function getOrderedEligibleIdeaIds(uint256 optLimiter) public view returns (uint96[] memory orderedEligibleIds);
```

**Parameters**

| Name         | Type      | Description                                                                                                                                                                                              |
| ------------ | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `optLimiter` | `uint256` | An optional limiter used to define the number of desired `ideaIds`, for example the number of eligible proposers or winning ids. If provided, it will be used to define the length of the returned array |

### getOrderedProposedIdeaIds

Intended for external use for improved devX

_Returns IDs of ideas which have already won waves and been proposed to Nouns governance_

```solidity
function getOrderedProposedIdeaIds() public view returns (uint96[] memory orderedProposedIds);
```

### getIdeaInfo

_Returns the IdeaInfo struct associated with a given `ideaId`_

```solidity
function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory);
```

### getParentWaveId

_Returns the `waveId` representing the parent Wave during which the given `ideaId` was created_

```solidity
function getParentWaveId(uint256 ideaId) external view returns (uint256 waveId);
```

### getSponsorshipInfo

_Returns the SponsorshipParams struct associated with a given `sponsor` address and `ideaId`_

```solidity
function getSponsorshipInfo(address sponsor, uint256 ideaId) public view returns (SponsorshipParams memory);
```

### getClaimableYield

_Returns the funds available to claim for a Nounder who has delegated to Wave_

```solidity
function getClaimableYield(address nounder) external view returns (uint256);
```

### getOptimisticYieldEstimate

Returned estimate is based on optimistic state and is subject to change until Wave finalization

_Returns an estimate of expected yield for the given Nounder LP who has delegated voting power to Wave_

```solidity
function getOptimisticYieldEstimate(address nounder) external view returns (uint256 yieldEstimate);
```

### getWaveInfo

_Returns information pertaining to the given Wave ID as a `WaveInfo` struct_

```solidity
function getWaveInfo(uint256 waveId) public view returns (WaveInfo memory);
```

### getCurrentWaveInfo

_Returns information pertaining to the current Wave as a `WaveInfo` struct_

```solidity
function getCurrentWaveInfo() external view returns (uint256 currentWaveId, WaveInfo memory currentWaveInfo);
```

### getNextIdeaId

_Returns the next `ideaId` which makes use of the `tokenId` mechanic from the ERC1155 standard_

```solidity
function getNextIdeaId() public view returns (uint256);
```

### \_validateIdeaCreation

```solidity
function _validateIdeaCreation(NounsDAOV3Proposals.ProposalTxs calldata _ideaTxs, string calldata _description)
    internal;
```

### \_sponsorIdea

```solidity
function _sponsorIdea(uint96 _ideaId) internal;
```

### \_updateWaveState

```solidity
function _updateWaveState() internal returns (uint256 previousWaveId);
```

### \_processWinningIdeas

```solidity
function _processWinningIdeas(
    uint96[] calldata _offchainWinningIds,
    string[] calldata _offchainDescriptions,
    uint96[] memory _winningIds
)
    internal
    returns (
        uint256 winningProposalsTotalFunding,
        IWave.Proposal[] memory winningProposals,
        ProposalInfo[] memory proposedIdeas
    );
```

### \_beforeTokenTransfer

```solidity
function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
) internal virtual override;
```

### \_authorizeUpgrade

```solidity
function _authorizeUpgrade(address) internal virtual override;
```
