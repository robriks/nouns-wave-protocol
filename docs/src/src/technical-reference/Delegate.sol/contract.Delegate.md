# Delegate
[Git Source](https://github.com/robriks/nouns-wave-protocol/blob/8e36481686ac36e51e7081db34b4cbe80e8add3b/src/Delegate.sol)

**Author:**
📯📯📯.eth

All Wave Protocol Delegate contracts are managed by the Wave Core. They are designed to receive
Nouns token delegation non-custodially so they can be used as proxies to push onchain proposals to Nouns governance.

For utmost security, Delegates never custody Nouns tokens and can only push proposals


## State Variables
### waveCore

```solidity
address public immutable waveCore;
```


## Functions
### constructor


```solidity
constructor(address waveCore_);
```

### pushProposal


```solidity
function pushProposal(
    INounsDAOLogicV3 governor,
    NounsDAOV3Proposals.ProposalTxs calldata txs,
    string calldata description
) external returns (uint256 nounsProposalId);
```

## Errors
### NotWaveCore

```solidity
error NotWaveCore(address caller);
```

