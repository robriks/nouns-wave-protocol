# Overview

Wave Protocol accepts Nouns token voting power noncustodially via delegation, leveraging optimistic state to compensate registered Noun delegators with yield in exchange for delegating their voting power. The yield comprises the total funds raised by each Wave's winning ideas, which are represented as ERC1155 tokens.

Idea tokens that amass the highest capital from Sponsors are selected as winners at the conclusion of each Wave, the crowdfunding period during which ideas can be created and sponsored. The Wave Core contract determines the number of winning ideas per Wave and validates optimistic state at finalization based on its available "liquidity" (ie voting power) which it uses to push onchain proposals to the Nouns Governor.

## Architecture Overview

Wave consists of three major parts: the IdeaTokenHub ERC1155 auction mechanism, the Wave Core contract, and Delegates which are used to push winning proposals to Nouns governance contracts.

- **IdeaTokenHub**
- **Wave Core**
- **Delegates**

### IdeaTokenHub: Wave's hub of ERC1155 tokens representing ideas for Nouns proposals

The IdeaTokenHub handles tokenization and crowdfunding of permissionlessly submitted ideas for new Nouns governance proposals. Each idea is represented as a unique ERC1155 `tokenId`, which enables permissionless on-chain sponsorship, ie lobbying via ERC1155 mint. Competition for pushing an idea token through to Nouns governance is introduced through a crowdfunding auction called a "Wave". At the conclusion of each Wave, tokenized ideas with the most funding are selected as winners and officially proposed into the Nouns governance system by leveraging the proposal power delegated to Wave Protocol by Nouns tokenholder LPs.

#### Liquidity Caveat: How many ideas per Wave win to become Nouns proposals?

Since Wave Protocol determines the number of winning ideas per Wave at finalization time, based on its available "liquidity" (ie voting power) which it uses to push onchain proposals to the Nouns Governor, the protocol must validate registered optimistic state at that time.

As a result, Wave Protocol has no control and no awareness of the Nouns token's voting power ledger other than at Wave finalization time. The permissionless nature of the Nouns token smart contract means Nounders may undelegate, transfer, sell, or burn during the interim period between Wave finalizations. To properly record expected liquidity in the Wave contracts and thereby compensate yield to the correct LPs, Nounders intending to provide voting power must optimistically register their voting power with Wave.

This means liquidity conditions at Wave finalization is subject to change up until the finalization transaction. To handle these externalities on the Nouns token contract, Wave's liquidity conditions are evaluated only at the moment of finalization. These liquidity conditions dictate the number of winning ideas for the current Wave and as a result the number of Nouns proposals pushed by a given Wave.

### Wave Core: Central processing unit that coordinates Wave protocol entities

To perform official onchain proposals to Nouns governance, the Wave Core contract manages a set of deterministically derived Delegate contracts. These Delegate contracts are designed for one sole purpose: to non-custodially receive delegation from Noun token holders and push onchain proposals to the Nouns governance ecosystem. Nouns NFT holders who delegate to Wave are compensated for lending their voting power to the protocol (which grants it ability to create proposals on their behalf) in the form of yield earned from idea Sponsors who competitively lobby for turning ideas into Nouns proposals.

#### Delegation Caveats

One caveat worth noting is that since Nouns voting power delegation is all-or-nothing on an address basis, Noun token holders can only delegate (and earn yield) on Nouns token balances up to the proposal threshold per wallet address. At time of writing, this is 2 Nouns NFTs. Extra voting power of a Nounder LP beyond the proposal threshold (ie > 2 Nouns held by a delegator address) cannot be used by Wave Protocol

Furthermore, in order to enable Nounders' retension of the right to vote even while lending their voting power, registered delegations are handled optimistically and resolved at proposal time due to the fact that delegations can be revoked directly on the Nouns token contract. For Nounders who wish to vote on other proposals while still participating in Wave Protocol, see [more information about undelegating from Wave to vote and then redelegating to collect yield](../tutorials/Wave-LP-Voting).

### Delegates: Proposal-pushers that interface with onchain Nouns governance contracts

All Wave Protocol Delegate contracts are deterministically derived via CREATE2 and their voting power liquidity is managed by the Wave Core. They are designed to receive Nouns token delegation non-custodially so they can be used as proxies to push onchain proposals to Nouns governance at Wave finalization.

For utmost security, Delegates never custody Nouns tokens and can only push proposals.
