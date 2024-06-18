# Introducing Wave Protocol

Introducing Wave Protocol, an onchain crowdfunding system extending the onchain Nouns Governance ecosystem to democratize access to creating Nouns proposals and to galvanize contributions by peripheral community members by removing the barrier of entry to the Nouns sphere.

## By Markus Osterlund, Protocol Lead @Wave

### Aligning incentives to turn Nouns NFTs into productive assets and achieve a bigger builder mindshare

Even with the correction in NFT market prices over the past couple years, the upfront capital cost of many NFTs still remains out of reach for many onchain participants. One such example is the Nouns governance token, which at time of writing boasts a $24,500 market price per NFT. Further, submitting an onchain proposal for consideration by the Nouns DAO requires two Nouns token votes, doubling the barrier of entry to a sizable $49,000.

What if ideas for Nouns proposals could come from anyone regardless of their tokenholdings and be judged on their merit, competing for selection before even hitting the canonical Nouns governance contracts as an official proposal? What if Nouns tokenholders could **noncustodially** earn yield from the competition and sponsorship of pre-proposal ideas? Builder mindshare would be extended beyond the ideations of those with expensive tokens, resulting in higher quality Nouns proposals and turning the Nouns NFT to a productive asset capable of generating yield.

Enter Wave Protocol, formerly known as PropLot.

## Understanding Wave Protocol

At its heart, Wave Protocol offers "Nouns governance proposals as a service" to peripheral community builders, termed "Idea Creators", who may not be capitalized enough to afford the 2 Nouns NFTs required to push their proposal onchain. The result is democratization of access to the Nouns sphere by lowering the barrier of entry for anyone with a worthy idea and desire to contribute.

### For Nouns tokenholders looking to earn yield on their NFTs without giving up custody

todo

### For Idea Creators aiming to create a Nouns proposal to be voted on by the DAO

todo

### For Idea Sponsors who wish to financially support a pre-proposal idea

todo

### The Nouns token's delegation ledger

Wave makes use of currently unproductive Nouns token voting power to engender a competitive idea machine powered by the untapped market of non-tokenholder mindshare. This is made possible by the Nouns NFT's second onchain ledger: the delegation ledger.

Those familiar with governance tokens may remember that the ERC721 implementation pioneered by Compound Bravo provides two ledgers: one for ownership and one used to record voting power and delegation thereof.

The ownership ledger is likely most familiar to crypto users, handling transfers, sales, mints, and burns. In short, this ledger tabulates token balances reflecting which address owns which token.

In contrast, Nouns voting power is tabulated by a separate delegation ledger which is generally less well-understood. The delegation ledger manages onchain state of addresses' voting power without affecting the top-level ownership of the tokens themselves. Voting power is transferred between addresses entirely without needing tokens to change hands simply by delegating and undelegating from desired representatives. This is the ledger that the Nouns NFT relies on to distinguish which addresses are eligible to push an onchain proposal to Nouns governance for voting.

Economic incentives for each type of protocol participant (Nounders, Idea Creators, and Sponsors) are aligned by compensating Nouns token delegators with yield, granting Idea Creators competitive access to pushing Nouns proposals onchain, and Idea Sponsors with scouting provenance and lobbying opportunities.

# todo: sections targeting each protocol participant (holders, peripheral Nouns fans), include section on how Wave opens a new capital efficient and permissionless participation layer which is complementary to the Nouns governance layer:

Wave Protocol opens a new participation layer that protocolizes the evaluation of merit ideas before it is passed up to the upper echelon of the Nouns institution

Table of Contents

    Wave Protocol
        Table of Contents
        Protocol Overview
        Security Considerations
        Why extend Nouns governance?
        To run fuzz tests
        Live Deployments

Protocol Overview

Wave Protocol accepts Nouns token voting power noncustodially via delegation, leveraging optimistic state to compensate registered Noun delegators with yield in exchange for delegating their voting power. The yield comprises the total funds raised by each Wave's winning ideas, which are represented as ERC1155 tokens.

Idea tokens that amass the highest capital from Sponsors are selected as winners at the conclusion of each Wave, the crowdfunding period during which ideas can be created and sponsored. The Wave Core contract determines the number of winning ideas per Wave and validates optimistic state at finalization based on its available "liquidity" (ie voting power) which it uses to push onchain proposals to the Nouns Governor.
Security Considerations

To run, Wave Protocol is designed to require only noncustodial delegation of the Nouns token's ERC721CheckPointable voting power ledger, which is entirely separate from the token's ownership ledger. As a result, Wave Protocol never requires Nouns token approvals, transfers, or custody of any kind.

To provide voting power "liquidity" in exchange for yield, Nounder token holders need only lend their voting power by delegating and registering using the Wave UI and can rest assured that Wave Protocol does not ever touch the Nouns token's custodial ledger.
Why extend Nouns governance?

The Wave protocol introduces numerous benefits to all parties involved. It provides Nouns NFT holders with a way to earn yield on their Nouns tokens by noncustodially lending their voting power to the Wave protocol via delegation. Delegating to Wave thereby extends the right to make onchain proposals to addresses that don't hold Nouns tokens but would like to submit proposal ideas.
