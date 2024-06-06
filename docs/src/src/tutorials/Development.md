## Usage

The Wave protocol core contract provides numerous convenience functions to improve offchain devX by returning values relevant for developing offchain components.

### To view the current minimum votes required to submit an onchain proposal to Nouns governance

```solidity
function getCurrentMinRequiredVotes() external view returns (uint256 minRequiredVotes);
```

### To fetch the `delegateId` for a given delegate address

```solidity
function getDelegateId(address delegate) external view returns (uint256 delegateId);
```

### To fetch a suitable Wave delegate for a given user based on their Nouns token voting power. This is the address the tokenholder should delegate to, using the Nouns token contract `delegate()` function.

```solidity
/// @dev Returns a suitable delegate address for an account based on its voting power
function getSuitableDelegateFor(address nounder)
    external
    view
    returns (address delegate, uint256 minRequiredVotes);
```

### To search for an available delegate of a given type:

```solidity
/// @dev Returns either an existing delegate ID if one meets the given parameters, otherwise returns the next delegate ID
/// @param isSupplementary Whether or not to search for a Delegate that doesn't meet the current proposal threshold
/// @param minRequiredVotes Minimum votes to make a proposal. Must be more than current proposal threshold which is based on Nouns token supply
/// @return delegateId The ID of a delegate that matches the given criteria
function getDelegateIdByType(uint256 minRequiredVotes, bool isSupplementary)
    external
    view
    returns (uint256 delegateId);
```

### To view all existing "partial" Delegates, ie ones with voting power below the minimum required to make a proposal

```solidity
function getAllPartialDelegates()
    external
    view
    returns (uint256 minRequiredVotes, address[] memory partialDelegates);
```

### To get the number of currently expected winning ideas- ie the number of Delegates that are currently eligible to propose

```solidity
/// @dev Returns the number of existing Delegates currently eligible to make a proposal
function numEligibleProposerDelegates()
    external
    view
    returns (uint256 minRequiredVotes, uint256 numEligibleProposers);
```

### To view all existing Delegates that currently possess enough delegated voting power to push a Nouns proposal

```solidity
/// @dev Returns all existing Delegates currently eligible for making a proposal
function getAllEligibleProposerDelegates()
    external
    view
    returns (uint256 minRequiredVotes, uint256[] memory eligibleProposerIds);
```

The IdeaTokenHub likewise provides several convenience functions, some of which are listed below:

### To view all existing IdeaIds that are eligible for proposal sorted by funding

```solidity
/// @param optLimiter An optional limiter used to define the number of desired `ideaIds`, for example the number of
/// eligible proposers or winning ids. If provided, it will be used to define the length of the returned array
function getOrderedEligibleIdeaIds(uint256 optLimiter) external view returns (uint96[] memory orderedEligibleIds);
```

### To view the leading IdeaIds which are expected to win this wave and be proposed to Nouns governance

```solidity
/// @dev Returns an array of the current wave's leading IdeaIds where the array length is determined
/// by the protocol's number of available proposer delegates, fetched from the WaveCore contract
function getWinningIdeaIds() external view returns (uint256 minRequiredVotes, uint256 numEligibleProposers, uint96[] memory winningIds);
```

### To view information about an IdeaId

```solidity
/// @dev Returns the IdeaInfo struct associated with a given `ideaId`
function getIdeaInfo(uint256 ideaId) external view returns (IdeaInfo memory);
```

### To view all ideas which have won previous auctions and have already been proposed

```solidity
/// @dev Returns IDs of ideas which have already won waves and been proposed to Nouns governance
/// @notice Intended for external use for improved devX
function getOrderedProposedIdeaIds() external view returns (uint96[] memory orderedProposedIds);
```
