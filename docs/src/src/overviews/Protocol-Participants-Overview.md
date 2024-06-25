# Protocol Participants Overview

## User Flow

Wave Protocol participants can be split into three categories:

- Nouns Token LPs, who provide voting power liquidity to the protocol using the Nouns token's delegation ledger
- Idea Creators, who wish to contribute to the Nouns ecosystem with a worthy idea but lack the Nouns NFTs required to push a proposal onchain
- Idea Sponsors, who support existing ideas with funding in hopes that they win a Wave and are pushed onchain as a Nouns proposal (akin to lobbying)

### Nouns holders

Nouns tokenholders must delegate and then register their voting power to Wave via a call to the Nouns token contract using either the `delegate()` or `delegateBySig()` function, while providing a valid Delegate address.

Note: Identifying a suitable delegate for a given Nounder based on their Nouns NFT token balance and based on Wave's current liquidity can be achieved using the Wave Core contract's `getSuitableDelegateFor(address nounder)` view function.

Once voting power has been delegated to Wave, the tokenholder must register their delegation with Wave and thus their intent to provide proposal power. Registration updates this contract's storage to optimistically expect the registered voting power. Since delegation is performed directly on the Nouns token contract, this may change and is validated at the conclusion of each auction.

```solidity
/// @dev Updates this contract's storage to reflect delegations performed directly on the Nouns token contract
function registerDelegation(address nounder, uint256 delegateId, uint256 numNouns) external;
```

Using ECDSA signatures, Nouns tokenholders can simultaneously create a delegate (if it doesn't yet exist) and grant voting power to the delegate in a single function call. Because the Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures, it thus does not support smart contract signatures. In that case, smart contract wallets holding Nouns NFTs must call `delegate()` on the Nouns contract directly.

```solidity
/// @dev Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
function delegateBySig(WaveSignature calldata waveSig) external;
```

At the end of each wave, delegations deemed to have violated their optimistic registration are cleared and the remaining delegators whose voting power was legitimately provided to the protocol are marked eligible to claim their yield:

```solidity
/// @dev Provides a way to collect the yield earned by Nounders who have delegated to Wave
function claim() external returns (uint256 claimAmt);
```

### Idea Creators

Those who wish to submit a Nouns proposal idea for crowdfunding need simply to mint a new ERC1155 tokenId and provide a minimum funding amount.

```solidity
/// @dev Creates a new ERC1155 token referred to by its token ID, ie its `ideaId` identifier
/// @notice To combat spam and low-quality proposals, idea token creation requires a small minimum payment
/// The Ether amount paid to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
function createIdea(NounsDAOV3Proposals.ProposalTxs calldata ideaTxs, string calldata description)
    external
    payable
    returns (uint96 newIdeaId);
```

### Idea Sponsors

Those who wish to sponsor (ie lobby for) an existing Nouns proposal idea to improve its chances of winning the wave's auction and be pushed to the Nouns governance contracts onchain may do so by providing a funding amount greater than the minimum:

```solidity
/// @dev Sponsors the existing ERC1155 tokenized idea specified by its ID. The Ether amount paid
/// to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
/// @notice To incentivize smooth protocol transitions and continued rollover of auction waves,
/// sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed
function sponsorIdea(uint256 ideaId) external payable;
```
