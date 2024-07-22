# IWave
[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/interfaces/IWave.sol)

*Interface for interacting with the Wave protocol core contract*


## Functions
### initialize


```solidity
function initialize(
    address ideaTokenHub_,
    address nounsGovernor_,
    address nounsToken_,
    uint256 minSponsorshipAmount_,
    uint256 waveLength_,
    string memory uri
) external;
```

### pushProposals

May only be called by the Wave's ERC1155 Idea token hub at the conclusion of each 2-week wave

*Pushes the winning proposal onto the `nounsGovernor` to be voted on in the Nouns governance ecosystem
Checks for changes in delegation state on `nounsToken` contract and updates Wave recordkeeping accordingly*


```solidity
function pushProposals(Proposal[] calldata winningProposals)
    external
    payable
    returns (Delegation[] memory delegations, uint256[] memory nounsProposalIds);
```

### delegateBySig

The Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures and thus
does not support smart contract signatures. In that case, `delegate()` must be called on the Nouns contract directly

*Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
in a single function call. This is the most convenient option for standard wallets using EOA private keys*


```solidity
function delegateBySig(WaveSignature calldata waveSig) external;
```

### registerDelegation

Delegation to must have been performed via a call to the Nouns token contract using either the
`delegate()` or `delegateBySig()` function, having provided the correct Delegate address for the given ID

*Updates this contract's storage to reflect delegations performed directly on the Nouns token contract*

*Serves as an alternative to `delegateByDelegatecall()` for smart contract wallets*


```solidity
function registerDelegation(address nounder, uint256 delegateId) external;
```

### createDelegate

As the constructor argument is appended to bytecode, it affects resulting address, eliminating risk of DOS vector

*Deploys a Delegate contract deterministically via `create2`, using the `_nextDelegateId` as salt*


```solidity
function createDelegate() external returns (address delegate);
```

### getDelegateAddress

*Computes the counterfactual address for a given delegate ID whether or not it has been deployed*


```solidity
function getDelegateAddress(uint256 delegateId) external view returns (address delegate);
```

### getDelegateId

Intended for offchain devX convenience only; not used in a write capacity within protocol

*Returns the `delegateId` for a given delegate address by iterating over existing delegates to find a match*


```solidity
function getDelegateId(address delegate) external view returns (uint256 delegateId);
```

### getDelegateIdByType

*Returns either an existing delegate ID if one meets the given parameters, otherwise returns the next delegate ID*


```solidity
function getDelegateIdByType(uint256 minRequiredVotes, bool isSupplementary)
    external
    view
    returns (uint256 delegateId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`minRequiredVotes`|`uint256`|Minimum votes to make a proposal. Must be more than current proposal threshold which is based on Nouns token supply|
|`isSupplementary`|`bool`|Whether or not to search for a Delegate that doesn't meet the current proposal threshold|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`delegateId`|`uint256`|The ID of a delegate that matches the given criteria|


### getNextDelegateId

*Typecasts and returns the next delegate ID as a `uint256`*


```solidity
function getNextDelegateId() external view returns (uint256 nextDelegateId);
```

### getSuitableDelegateFor

*Returns a suitable delegate address for an account based on its voting power*


```solidity
function getSuitableDelegateFor(address nounder) external view returns (address delegate, uint256 minRequiredVotes);
```

### getCurrentMinRequiredVotes

*Returns the current minimum votes required to submit an onchain proposal to Nouns governance*


```solidity
function getCurrentMinRequiredVotes() external view returns (uint256 minRequiredVotes);
```

### getAllPartialDelegates

*Returns all existing Delegates with voting power below the minimum required to make a proposal
Provided to improve offchain devX; returned values can change at any time as Nouns ecosystem is external*


```solidity
function getAllPartialDelegates() external view returns (uint256 minRequiredVotes, address[] memory partialDelegates);
```

### numEligibleProposerDelegates

*Returns the number of existing Delegates currently eligible to make a proposal*


```solidity
function numEligibleProposerDelegates()
    external
    view
    returns (uint256 minRequiredVotes, uint256 numEligibleProposers);
```

### getAllEligibleProposerDelegates

*Returns all existing Delegates currently eligible for making a proposal
Provided to improve offchain devX: returned values can change at any time as Nouns ecosystem is external*


```solidity
function getAllEligibleProposerDelegates()
    external
    view
    returns (uint256 minRequiredVotes, uint256[] memory eligibleProposerIds);
```

### getOptimisticDelegations

*Returns optimistic delegations from storage. These are subject to change and should never be relied upon*


```solidity
function getOptimisticDelegations() external view returns (Delegation[] memory);
```

### computeNounsDelegationDigest

*Convenience function to facilitate offchain development by computing the `delegateBySig()` digest
for a given signer and expiry*


```solidity
function computeNounsDelegationDigest(address signer, uint256 delegateId, uint256 expiry)
    external
    view
    returns (bytes32 digest);
```

## Events
### DelegateCreated

```solidity
event DelegateCreated(address delegate, uint256 id);
```

### DelegationRegistered

```solidity
event DelegationRegistered(Delegation optimisticDelegation);
```

### DelegationDeleted

```solidity
event DelegationDeleted(Delegation disqualifiedDelegation);
```

## Errors
### Unauthorized

```solidity
error Unauthorized();
```

### InsufficientDelegations

```solidity
error InsufficientDelegations();
```

### NotDelegated

```solidity
error NotDelegated(address nounder, address delegate);
```

### InsufficientVotingPower

```solidity
error InsufficientVotingPower(address nounder);
```

### DelegateSaturated

```solidity
error DelegateSaturated(uint256 delegateId);
```

### InvalidDelegateId

```solidity
error InvalidDelegateId(uint256 delegateId);
```

### InvalidDelegateAddress

```solidity
error InvalidDelegateAddress(address delegate);
```

### InvalidSignature

```solidity
error InvalidSignature();
```

### OnlyDelegatecallContext

```solidity
error OnlyDelegatecallContext();
```

### Create2Failure

```solidity
error Create2Failure();
```

## Structs
### Delegation

```solidity
struct Delegation {
    address delegator;
    uint32 blockDelegated;
    uint16 votingPower;
    uint16 delegateId;
}
```

**Properties**

|Name|Type|Description|
|----|----|-----------|
|`delegator`|`address`|Only token holder addresses are stored since Delegates can be derived|
|`blockDelegated`|`uint32`|Block at which a Noun was delegated, used for payout calculation. Only records delegations performed via this contract, ie not direct delegations on Nouns token|
|`votingPower`|`uint16`|Voting power can safely be stored in a uint16 as the type's maximum represents 179.5 years of Nouns token supply issuance (at a rate of one per day)|
|`delegateId`|`uint16`||

### WaveSignature

```solidity
struct WaveSignature {
    address signer;
    uint256 delegateId;
    uint256 numNouns;
    uint256 nonce;
    uint256 expiry;
    bytes signature;
}
```

### Proposal

```solidity
struct Proposal {
    NounsDAOProposals.ProposalTxs ideaTxs;
    string description;
}
```

