# IERC721Checkpointable
[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/interfaces/IERC721Checkpointable.sol)

*Interface for interacting with the Nouns ERC721 governance token with minimal deployment bytecode overhead*


## Functions
### name

Returns the name of the ERC721 token


```solidity
function name() external view returns (string memory);
```

### decimals

Defines decimals as per ERC-20 convention to make integrations with 3rd party governance platforms easier


```solidity
function decimals() external returns (uint8);
```

### checkpoints

A record of votes checkpoints for each account, by index


```solidity
function checkpoints(address account, uint32 index) external view returns (Checkpoint memory);
```

### numCheckpoints

The number of checkpoints for each account


```solidity
function numCheckpoints(address account) external returns (uint32);
```

### DOMAIN_TYPEHASH

The EIP-712 typehash for the contract's domain


```solidity
function DOMAIN_TYPEHASH() external view returns (bytes32);
```

### DELEGATION_TYPEHASH

The EIP-712 typehash for the delegation struct used by the contract


```solidity
function DELEGATION_TYPEHASH() external view returns (bytes32);
```

### nonces

A record of states for signing / validating signatures


```solidity
function nonces(address account) external view returns (uint256);
```

### votesToDelegate

The votes a delegator can delegate, which is the current balance of the delegator.


```solidity
function votesToDelegate(address delegator) external view returns (uint96);
```

### delegates

Overrides the standard `Comp.sol` delegates mapping to return delegator's own address if they haven't delegated.


```solidity
function delegates(address delegator) external view returns (address);
```

### delegate

Delegate votes from `msg.sender` to `delegatee`


```solidity
function delegate(address delegatee) external;
```

### delegateBySig

Delegates votes from signatory to `delegatee`


```solidity
function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;
```

### getCurrentVotes

Gets the current votes balance for `account`


```solidity
function getCurrentVotes(address account) external view returns (uint96);
```

### getPriorVotes

Determine the prior number of votes for an account as of a block number


```solidity
function getPriorVotes(address account, uint256 blockNumber) external view returns (uint96);
```

## Structs
### Checkpoint
A checkpoint for marking number of votes from a given block


```solidity
struct Checkpoint {
    uint32 fromBlock;
    uint96 votes;
}
```

