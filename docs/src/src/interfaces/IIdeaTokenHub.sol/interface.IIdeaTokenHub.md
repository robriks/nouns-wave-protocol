# IIdeaTokenHub
[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/interfaces/IIdeaTokenHub.sol)

*Interface for interacting with the Wave IdeaTokenHub contract which manages tokenized ideas via ERC1155*


## Functions
### minSponsorshipAmount


```solidity
function minSponsorshipAmount() external view returns (uint256);
```

### decimals


```solidity
function decimals() external view returns (uint256);
```

### waveLength


```solidity
function waveLength() external view returns (uint256);
```

### initialize


```solidity
function initialize(
    address owner_,
    address nounsGovernor_,
    uint256 minSponsorshipAmount_,
    uint256 waveLength_,
    string memory uri_
) external;
```

### createIdea

To combat spam and low-quality proposals, idea token creation requires a small minimum payment
The Ether amount paid to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio

*Creates a new ERC1155 token referred to by its token ID, ie its `ideaId` identifier*


```solidity
function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description)
    external
    payable
    returns (uint96 newIdeaId);
```

### sponsorIdea

To incentivize smooth protocol transitions and continued rollover of auction waves,
sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed

*Sponsors the existing ERC1155 tokenized idea specified by its ID. The Ether amount paid
to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio*


```solidity
function sponsorIdea(uint96 ideaId) external payable;
```

### sponsorIdeaWithReason

To incentivize smooth protocol transitions and continued rollover of auction waves,
sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed

*Idential execution to `sponsorIdea()` emitting a separate event with additional description string*


```solidity
function sponsorIdeaWithReason(uint96 ideaId, string calldata reason) external payable;
```

### finalizeWave

*Finalizes a Wave wave, marking the end of an auction wave. Winning ideas are selected by the highest
sponsored balances and officially proposed to the Nouns governance contracts. The number of winners varies
depending on the available 'liquidity' of lent Nouns NFTs and their proposal power. Yield distributions are
tallied by calling the Wave Core and recording valid delegations in the `claimableYield` mapping where they
can then be claimed at any time by a Nouns holder who has delegated to Wave*


```solidity
function finalizeWave(uint96[] calldata offchainWinningIds, string[] calldata offchainDescriptions)
    external
    returns (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds);
```

### claim

Reentrance prevented via CEI

*Provides a way to collect the yield earned by Nounders who have delegated to Wave for a full wave*


```solidity
function claim() external returns (uint256 claimAmt);
```

### setMinSponsorshipAmount

Only callable by the owner

*Sets the new minimum funding required to create and sponsor tokenized ideas*


```solidity
function setMinSponsorshipAmount(uint256 newMinSponsorshipAmount) external;
```

### setWaveLength

Only callable by the owner

*Sets the new length of Wave waves in blocks*


```solidity
function setWaveLength(uint256 newWavelength) external;
```

### getWinningIdeaIds

*Returns an array of the current wave's leading IdeaIds where the array length is determined
by the protocol's number of available proposer delegates, fetched from the WaveCore contract*


```solidity
function getWinningIdeaIds()
    external
    view
    returns (uint256 minRequiredVotes, uint256 numEligibleProposers, uint96[] memory winningIds);
```

### getOrderedEligibleIdeaIds

*Fetches an array of `ideaIds` eligible for proposal, ordered by total funding*


```solidity
function getOrderedEligibleIdeaIds(uint256 optLimiter) external view returns (uint96[] memory orderedEligibleIds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`optLimiter`|`uint256`|An optional limiter used to define the number of desired `ideaIds`, for example the number of eligible proposers or winning ids. If provided, it will be used to define the length of the returned array|


### getOrderedProposedIdeaIds

Intended for external use for improved devX

*Returns IDs of ideas which have already won waves and been proposed to Nouns governance*


```solidity
function getOrderedProposedIdeaIds() external view returns (uint96[] memory orderedProposedIds);
```

### getIdeaInfo

*Returns the IdeaInfo struct associated with a given `ideaId`*


```solidity
function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory);
```

### getSponsorshipInfo

*Returns the SponsorshipParams struct associated with a given `sponsor` address and `ideaId`*


```solidity
function getSponsorshipInfo(address sponsor, uint256 ideaId) external view returns (SponsorshipParams memory);
```

### getClaimableYield

*Returns the funds available to claim for a Nounder who has delegated to Wave*


```solidity
function getClaimableYield(address nounder) external view returns (uint256);
```

### getOptimisticYieldEstimate

Returned estimate is based on optimistic state and is subject to change until Wave finalization

*Returns an estimate of expected yield for the given Nounder LP who has delegated voting power to Wave*


```solidity
function getOptimisticYieldEstimate(address nounder) external view returns (uint256 yieldEstimate);
```

### getWaveInfo

*Returns information pertaining to the given Wave ID as a `WaveInfo` struct*


```solidity
function getWaveInfo(uint256 waveId) external view returns (WaveInfo memory);
```

### getCurrentWaveInfo

*Returns information pertaining to the current Wave as a `WaveInfo` struct*


```solidity
function getCurrentWaveInfo() external view returns (uint256 currentWaveId, WaveInfo memory currentWaveInfo);
```

### getParentWaveId

*Returns the `waveId` representing the parent Wave during which the given `ideaId` was created*


```solidity
function getParentWaveId(uint256 ideaId) external view returns (uint256 waveId);
```

### getNextIdeaId

*Returns the next `ideaId` which makes use of the `tokenId` mechanic from the ERC1155 standard*


```solidity
function getNextIdeaId() external view returns (uint256);
```

## Events
### IdeaCreated

```solidity
event IdeaCreated(IWave.Proposal idea, address creator, uint96 ideaId, SponsorshipParams params);
```

### Sponsorship

```solidity
event Sponsorship(address sponsor, uint96 ideaId, SponsorshipParams params, string reason);
```

### WaveFinalized

```solidity
event WaveFinalized(ProposalInfo[] proposedIdeas, WaveInfo previousWaveInfo);
```

## Errors
### BelowMinimumSponsorshipAmount

```solidity
error BelowMinimumSponsorshipAmount(uint256 value);
```

### InvalidActionsCount

```solidity
error InvalidActionsCount(uint256 count);
```

### ProposalInfoArityMismatch

```solidity
error ProposalInfoArityMismatch();
```

### InvalidOffchainDataProvided

```solidity
error InvalidOffchainDataProvided();
```

### InvalidDescription

```solidity
error InvalidDescription();
```

### NonexistentIdeaId

```solidity
error NonexistentIdeaId(uint256 ideaId);
```

### AlreadyProposed

```solidity
error AlreadyProposed(uint256 ideaId);
```

### WaveIncomplete

```solidity
error WaveIncomplete();
```

### ClaimFailure

```solidity
error ClaimFailure();
```

### Soulbound

```solidity
error Soulbound();
```

## Structs
### WaveInfo

```solidity
struct WaveInfo {
    uint32 startBlock;
    uint32 endBlock;
}
```

### IdeaInfo

```solidity
struct IdeaInfo {
    uint216 totalFunding;
    uint32 blockCreated;
    bool isProposed;
    NounsDAOV3Proposals.ProposalTxs proposalTxs;
}
```

### SponsorshipParams

```solidity
struct SponsorshipParams {
    uint216 contributedBalance;
    bool isCreator;
}
```

### ProposalInfo

```solidity
struct ProposalInfo {
    uint256 nounsProposalId;
    uint256 waveIdeaId;
    uint216 totalFunding;
    uint32 blockCreated;
}
```

