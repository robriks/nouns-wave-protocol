# PropLot Protocol

PropLot Protocol is a decentralized system built on top of the Nouns Governance ecosystem to noncustodially and permissionlessly democratize access to the Nouns sphere and lower the barrier of entry so that anyone with a worthy Nouns governance idea may participate and make a difference.

## Why extend Nouns governance?

The PropLot protocol introduces numerous benefits to all parties involved. It provides Nouns NFT holders with a way to earn yield on their Nouns tokens by noncustodially lending their voting power to the PropLot protocol via delegation. Delegating to PropLot thereby extends the right to make onchain proposals to addresses that don't hold Nouns tokens but would like to submit proposal ideas.

### On security

The protocol is designed with maximal attention to security; since voting power is simply delegated noncustodially to PropLot contracts, there is no requirement for any kind of approval, transfer, or other action which could compromise the ownership of the Nouns NFTs. Only the voting power of the Nouns token's `ERC721Checkpointable` ledger is ever required to participate in PropLot and earn yield.

## Architecture Overview

PropLot consists of three major parts: the IdeaTokenHub ERC1155 auction mechanism, the PropLot Core contract, and Delegates which are used to push winning proposals to Nouns governance contracts.

### IdeaTokenHub

The IdeaTokenHub handles tokenization and crowdfunding of permissionlessly submitted ideas for new Nouns governance proposals. Each idea is represented as a unique ERC1155 tokenId, which enables permissionless on-chain minting. Competition for pushing an idea token through to Nouns governance is introduced through a crowdfunding auction called a "wave". Tokenized ideas with the most funding at the end of each auction are officially proposed into the Nouns governance system by leveraging proposal power lent/delegated to PropLot by Nouns tokenholders.

### PropLot Core

To perform official onchain proposals to Nouns governance, the PropLot Core contract manages a set of deterministically derived Delegate contracts. These Delegate contracts are designed for a single function: to non-custodially receive delegation from Noun token holders and push onchain proposals to the Nouns governance ecosystem. Nouns NFT holders who delegate to PropLot are compensated for granting the protocol the ability to create proposals on their behalf in the form of earning yield.

One caveat worth noting is that since Nouns voting power delegation is all-or-nothing on an address basis, Noun token holders can only delegate (and earn yield) on Nouns token balances up to the proposal threshold per wallet address. Furthermore, registered delegations are handled optimistically and resolved at proposal time due to the fact that delegations can be revoked directly on the Nouns token contract.

### Delegates

All PropLot Protocol Delegate contracts are managed by the PropLot Core. They are designed to receive Nouns token delegation non-custodially so they can be used as proxies to push onchain proposals to Nouns governance.

For utmost security, Delegates never custody Nouns tokens and can only push proposals.

## User Flow

### Nouns holders

Nouns tokenholders must delegate their voting power to PropLot via a call to the Nouns token contract using either the `delegate()` or `delegateBySig()` function, while providing a valid Delegate address. Functions for selecting a suitable delegate for a Nouns holder can be referenced in the "Usage" section below.

Once voting power has been delegated to PropLot, the tokenholder must register their delegation with PropLot and thus their intent to provide proposal power. Registration updates this contract's storage to optimistically expect the registered voting power. Since delegation is performed directly on the Nouns token contract, this may change and is validated at the conclusion of each auction.

```solidity
/// @dev Updates this contract's storage to reflect delegations performed directly on the Nouns token contract
function registerDelegation(address nounder, uint256 delegateId, uint256 numNouns) external;
```

Using ECDSA signatures, Nouns tokenholders can simultaneously create a delegate (if it doesn't yet exist) and grant voting power to the delegate in a single function call. Because the Nouns ERC721Checkpointable implementation only supports standard EOA ECDSA signatures, it thus does not support smart contract signatures. In that case, smart contract wallets holding Nouns NFTs must call `delegate()` on the Nouns contract directly.

```solidity
/// @dev Simultaneously creates a delegate if it doesn't yet exist and grants voting power to the delegate
function delegateBySig(PropLotSignature calldata propLotSig) external;
```

At the end of each wave, delegations deemed to have violated their optimistic registration are cleared and the remaining delegators whose voting power was legitimately provided to the protocol are marked eligible to claim their yield:

```solidity
/// @dev Provides a way to collect the yield earned by Nounders who have delegated to PropLot
function claim() external returns (uint256 claimAmt);
```

### Idea proposers

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

Those who wish to sponsor an existing Nouns proposal idea to improve its chances of winning the wave's auction and be pushed to the Nouns governance contracts onchain may do so by providing a funding amount greater than the minimum:

```solidity
/// @dev Sponsors the existing ERC1155 tokenized idea specified by its ID. The Ether amount paid
/// to create the idea will be reflected in the creator's ERC1155 balance in a 1:1 ratio
/// @notice To incentivize smooth protocol transitions and continued rollover of auction waves,
/// sponsorship attempts are reverted if the wave period has passed and `finalizeWave()` has not been executed
function sponsorIdea(uint256 ideaId) external payable;
```

## To run fuzz tests

```shell
$ forge test
```

## Usage

The PropLot protocol core contract provides numerous convenience functions to improve offchain devX by returning values relevant for developing offchain components. Note that many of these values can change at any time as the Nouns ecosystem is external to PropLot and its state changes may affect the results of the following view functions.

### To view the current minimum votes required to submit an onchain proposal to Nouns governance

```solidity
function getCurrentMinRequiredVotes() external view returns (uint256 minRequiredVotes);
```

### To fetch a suitable PropLot delegate for a given user based on their Nouns token voting power. This is the address the tokenholder should delegate to, using the Nouns token contract `delegate()` function.

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
/// by the protocol's number of available proposer delegates, fetched from the PropLotCore contract
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

## Live Deployments

PropLot protocol is currently deployed to Base Sepolia testnet for backend & frontend development and finalized Ethereum mainnet deployments are coming soon.

IdeaTokenHub (harness, proxy): `0xaB626b93B3f98d79ae1FBf6c76Bf678F83E7faf3`
PropLot (harness, proxy): `0xD49c56d08D3c40854c0543bA5B1747f2Ad1c7b89`
NounsToken (harness): `0x1B8D11880fe221B51FC814fF4C41366a91A59DEB`

Note that the above testnet contracts deployed to Base Sepolia network are harnesses to expose convenience functions that would normally otherwise be protected to expedite development.
