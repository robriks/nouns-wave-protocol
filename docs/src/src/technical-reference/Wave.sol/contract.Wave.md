# Wave

[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/Wave.sol)

**Inherits:**
Ownable, UUPSUpgradeable, [IWave](/src/interfaces/IWave.sol/interface.IWave.md)

**Author:**
📯📯📯.eth

## State Variables

### nounsGovernor

```solidity
INounsDAOLogicV3 public nounsGovernor;
```

### nounsToken

```solidity
IERC721Checkpointable public nounsToken;
```

### \_\_creationCodeHash

```solidity
bytes32 private __creationCodeHash;
```

### ideaTokenHub

```solidity
IIdeaTokenHub public ideaTokenHub;
```

### \_optimisticDelegations

Since delegations can be revoked directly on the Nouns token contract, active delegations are handled optimistically

```solidity
Delegation[] private _optimisticDelegations;
```

### \_nextDelegateId

Declared as `uint16` type to efficiently pack into storage structs, but used as `uint256` or `bytes32`
when used as part of `create2` deployment or other function parameter

_Identifier used to derive and refer to the address of Delegate proxy contracts_

```solidity
uint16 private _nextDelegateId;
```

## Functions

### constructor

```solidity
constructor();
```

### initialize

```solidity
function initialize(
    address ideaTokenHub_,
    address nounsGovernor_,
    address nounsToken_,
    uint256 minSponsorshipAmount_,
    uint256 waveLength_,
    string memory uri
) public virtual initializer;
```

### pushProposals

May only be called by the Wave's ERC1155 Idea token hub at the conclusion of each 2-week wave

_Pushes the winning proposal onto the `nounsGovernor` to be voted on in the Nouns governance ecosystem
Checks for changes in delegation state on `nounsToken` contract and updates Wave recordkeeping accordingly_

```solidity
function pushProposals(IWave.Proposal[] calldata winningProposals)
    public
    payable
    returns (IWave.Delegation[] memory delegations, uint256[] memory nounsProposalIds);
```

### delegateBySig

The Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures and thus
does not support smart contract signatures. In that case, `delegate()` must be called on the Nouns contract directly

_Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
in a single function call. This is the most convenient option for standard wallets using EOA private keys_

```solidity
function delegateBySig(WaveSignature calldata waveSig) external;
```

### registerDelegation

Delegation to must have been performed via a call to the Nouns token contract using either the
`delegate()` or `delegateBySig()` function, having provided the correct Delegate address for the given ID

_Updates this contract's storage to reflect delegations performed directly on the Nouns token contract_

```solidity
function registerDelegation(address nounder, uint256 delegateId) external;
```

### createDelegate

As the constructor argument is appended to bytecode, it affects resulting address, eliminating risk of DOS vector

_Deploys a Delegate contract deterministically via `create2`, using the `_nextDelegateId` as salt_

```solidity
function createDelegate() public returns (address delegate);
```

### getDelegateAddress

_Computes the counterfactual address for a given delegate ID whether or not it has been deployed_

```solidity
function getDelegateAddress(uint256 delegateId) public view returns (address delegate);
```

### getDelegateId

Intended for offchain devX convenience only; not used in a write capacity within protocol

_Returns the `delegateId` for a given delegate address by iterating over existing delegates to find a match_

```solidity
function getDelegateId(address delegate) external view returns (uint256 delegateId);
```

### getDelegateIdByType

_Returns either an existing delegate ID if one meets the given parameters, otherwise returns the next delegate ID_

```solidity
function getDelegateIdByType(uint256 minRequiredVotes, bool isSupplementary) public view returns (uint256 delegateId);
```

**Parameters**

| Name               | Type      | Description                                                                                                         |
| ------------------ | --------- | ------------------------------------------------------------------------------------------------------------------- |
| `minRequiredVotes` | `uint256` | Minimum votes to make a proposal. Must be more than current proposal threshold which is based on Nouns token supply |
| `isSupplementary`  | `bool`    | Whether or not to search for a Delegate that doesn't meet the current proposal threshold                            |

**Returns**

| Name         | Type      | Description                                          |
| ------------ | --------- | ---------------------------------------------------- |
| `delegateId` | `uint256` | The ID of a delegate that matches the given criteria |

### getNextDelegateId

_Typecasts and returns the next delegate ID as a `uint256`_

```solidity
function getNextDelegateId() public view returns (uint256 nextDelegateId);
```

### getSuitableDelegateFor

_Returns a suitable delegate address for an account based on its voting power_

```solidity
function getSuitableDelegateFor(address nounder) external view returns (address delegate, uint256 minRequiredVotes);
```

### getCurrentMinRequiredVotes

_Returns the current minimum votes required to submit an onchain proposal to Nouns governance_

```solidity
function getCurrentMinRequiredVotes() public view returns (uint256 minRequiredVotes);
```

### getAllPartialDelegates

_Returns all existing Delegates with voting power below the minimum required to make a proposal
Provided to improve offchain devX; returned values can change at any time as Nouns ecosystem is external_

```solidity
function getAllPartialDelegates() external view returns (uint256 minRequiredVotes, address[] memory partialDelegates);
```

### numEligibleProposerDelegates

_Returns the number of existing Delegates currently eligible to make a proposal_

```solidity
function numEligibleProposerDelegates() public view returns (uint256 minRequiredVotes, uint256 numEligibleProposers);
```

### getAllEligibleProposerDelegates

_Returns all existing Delegates currently eligible for making a proposal
Provided to improve offchain devX: returned values can change at any time as Nouns ecosystem is external_

```solidity
function getAllEligibleProposerDelegates()
    public
    view
    returns (uint256 minRequiredVotes, uint256[] memory eligibleProposerIds);
```

### getOptimisticDelegations

Delegation array in storage is optimistic and should never be relied on externally

```solidity
function getOptimisticDelegations() public view returns (Delegation[] memory);
```

### computeNounsDelegationDigest

_Convenience function to facilitate offchain development by computing the `delegateBySig()` digest
for a given signer and expiry_

```solidity
function computeNounsDelegationDigest(address signer, uint256 delegateId, uint256 expiry)
    public
    view
    returns (bytes32 digest);
```

### \_findDelegateId

_Returns the id of the first delegate ID found to meet the given parameters
To save gas by minimizing costly SLOADs, terminates as soon as a delegate meeting the critera is found_

```solidity
function _findDelegateId(uint256 _minRequiredVotes, bool _isSupplementary) internal view returns (uint256 delegateId);
```

**Parameters**

| Name                | Type      | Description                                                                  |
| ------------------- | --------- | ---------------------------------------------------------------------------- |
| `_minRequiredVotes` | `uint256` | The votes needed to make a proposal, dynamic based on Nouns token supply     |
| `_isSupplementary`  | `bool`    | Whether or not the returned Delegate should accept fewer than required votes |

### \_disqualifiedDelegationIndices

_Returns an array of delegation IDs that violated the protocol rules and are ineligible for yield_

```solidity
function _disqualifiedDelegationIndices() internal view returns (uint256[] memory);
```

### \_isDisqualified

_Returns true for delegations that violated their optimistically registered parameters_

```solidity
function _isDisqualified(address _nounder, address _delegate, uint256 _votingPower)
    internal
    view
    returns (bool _disqualify);
```

### \_deleteDelegations

_Deletes Delegations by swapping the non-final index members to be removed with members to be preserved_

```solidity
function _deleteDelegations(uint256[] memory _indices) internal;
```

### \_sortIndicesDescending

_Sorts array of indices to be deleted in descending order so the remaining indexes are not disturbed via resizing_

```solidity
function _sortIndicesDescending(uint256[] memory _indices) internal pure returns (uint256[] memory);
```

### \_setOptimisticDelegation

```solidity
function _setOptimisticDelegation(Delegation memory _delegation) internal;
```

### \_checkForActiveProposal

_Returns true when an active proposal exists for the delegate, meaning it is ineligible to propose_

```solidity
function _checkForActiveProposal(address delegate) internal view returns (bool _noActiveProp);
```

### \_isEligibleProposalState

_References the Nouns governor contract to determine whether a proposal is in a disqualifying state_

```solidity
function _isEligibleProposalState(uint256 _latestProposal) internal view returns (bool);
```

### \_simulateCreate2

_Computes a counterfactual Delegate address via `create2` using its creation code and `delegateId` as salt_

```solidity
function _simulateCreate2(bytes32 _salt, bytes32 _creationCodeHash)
    internal
    view
    returns (address simulatedDeployment);
```

### \_authorizeUpgrade

```solidity
function _authorizeUpgrade(address) internal virtual override;
```
