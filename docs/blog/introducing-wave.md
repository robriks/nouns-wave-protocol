<div align="center" style="font-size: 1.5em;">

![](https://raw.githubusercontent.com/robriks/robriks/main/assets/wave.svg)

# Introducing Wave Protocol

</div>

#### Aligning incentives to democratize access to Nouns governance, transmogrify Nouns NFTs into productive yield-bearing assets, and harness wider builder mindshare

Introducing Wave Protocol, an onchain crowdfunding system that extends the onchain Nouns Governance ecosystem by improving access to Nouns proposal creation and galvanizes community contributions by removing the barrier of entry to the Nouns sphere.

## By Markus Osterlund, Protocol Lead @Wave

### Table of Contents

- [ Wave Protocol](#introducing-wave-protocol)
  - [Why extend Nouns governance?](#why-extend-nouns-governance)
  - [Solving existing problems in the Nouns sphere](#solving-existing-problems-in-the-nouns-sphere)
  - [Understanding Wave Protocol](#understanding-wave-protocol)
  - [For Nouns tokenholders: "LPs"](#for-nouns-tokenholders-lps)
  - [For Nouns builders: "Idea Creators"](#for-nouns-builders-idea-creators)
  - [For Nouns community contributors: "Idea Sponsors"](#for-nouns-community-contributors-idea-sponsors)

### Why extend Nouns governance?

Even with the correction in NFT market prices over recent years, the upfront capital cost of many NFTs still remains out of reach for many onchain participants. One such example is the Nouns governance token, which at time of writing boasts a $24,500 market price per NFT. Further, submitting an onchain proposal for consideration by the Nouns DAO requires two Nouns token votes, doubling the barrier of entry to a sizable $49,000.

What if ideas for Nouns proposals could come from anyone regardless of their tokenholdings and be judged on their merit, competing for selection before even hitting the canonical Nouns governance contracts as an official proposal? What if Nouns tokenholders could **noncustodially** earn yield from the competition and sponsorship of pre-proposal ideas? Builder mindshare would be extended beyond the ideations of those with expensive tokens, resulting in higher quality Nouns proposals and turning the Nouns NFT to a productive asset capable of generating yield.

**_Enter Wave Protocol, formerly known as PropLot._**

### Solving existing problems in the Nouns sphere

Wave Protocol solves three core issues facing the Nouns ecosystem:

1. Getting a Nouns idea onchain to the voting stage is challenging
2. Nouns is capital constrained and needs to invent new ways to fund itself aside from the daily auction
3. Newcomers to Nouns do not have clear contributor highways

#### Removing the barrier of entry for community contributors

Without owning two Nouns NFTs outright in order to push a proposal, getting an idea in front of the Nouns DAO for voting is difficult. You'll either need to know people who will delegate their votes to you or you'll need to put up a candidate proposal and simply hope that the public carries it to the finish line.

We believe there is a better way to get your idea onchain than playing social & political games. As things stand, Nouns has a contributor highway problem. If you have an idea for contribution and want to get it funded, it’s not clear what steps to take. By protocolizing the process for getting an idea on-chain, we aim to provide a clear, meritocratic path for pre-proposal ideas which will result in more contributor ideas as well as more excitement for Nouns governance.

#### Innovating with new funding mechanisms for Nouns tokenholders and for the DAO

At current spend trajectories, Nouns DAO's capitalization amounts to anywhere from 8-14 months of runway before the treasury is completely dry. Like it or not, the DAO needs more ways of funding its treasury that are independent of the daily issuance auction. Further, the treasury owns 560 idle Nouns NFTs whose voting power is not utilized.

Noncustodially allocating a handful of idle treasury Nouns to Wave Protocol would monetize their voting power and fund the treasury in a novel way via delegation, without requiring the tokens to change hands.

#### Providing a public arena for community members who wish to contribute, enabling a public track record of builder provenance for scouting purposes.

For peripheral contributors, it is difficult to secure a delegate or even to be taken seriously on the governance forum and other public platforms like Twitter and Warpcast. Currently, those without voting power can participate by “supporting” a proposal and leaving a VWR but it can sometimes feel futile to do so since there is no guarantee that your efforts gain traction, no refund available for support actions, and no recognition for consistent support without existing builder provenance & reputation.

Wave protocol offers a new avenue for addressing these issues — _the scout model_.

In the traditional Venture Capital world, scouts help VCs with deal flow by sourcing startups and sending them to partners at the firm. In a similar vein, “nouns scouts” can use Wave Protocol to mint (ie sponsor) ideas that they believe should make it to the voting stage. Since sponsors receive an ERC1155 token as a receipt for supporting ideas, scouts build soulbound reputation over time, showcasing their ability to source contributions, ideas, and talented builders. In short, Wave introduces a new way of building soulbound social capital in the Nouns ecosystem.

### Understanding Wave Protocol

#### [For those interested in a Wave Protocol deep dive, consult our documentation](https://nouns-wave-protocol.vercel.app/)

At its heart, Wave Protocol offers "Nouns governance proposals as a service" to peripheral community builders, termed "Idea Creators", who may not be capitalized enough to afford the 2 Nouns NFTs required to push their proposal onchain. The result is democratization of access to the Nouns sphere by lowering the barrier of entry for anyone with a worthy idea and desire to contribute.

Wave Protocol accepts Nouns token voting power **noncustodially via delegation** (more on this below), leveraging optimistic state to compensate registered Noun delegators with yield in exchange for delegating their voting power. The yield comprises the total funds raised by each Wave's winning ideas, which are represented as ERC1155 tokens.

Idea tokens that amass the highest capital from Sponsors are selected as winners at the conclusion of each Wave, the crowdfunding period during which ideas can be created and sponsored. The Wave Core contract determines the number of winning ideas per Wave and validates optimistic state at finalization based on its available "liquidity" (ie voting power) which it uses to push onchain proposals to the Nouns Governor.

In short, Wave Protocol opens a new participation layer that protocolizes the evaluation of ideas' merit before they are passed up to the upper echelon of the Nouns institution for voting.

### The Nouns token's delegation ledger

Wave makes use of idle Nouns token voting power to engender a competitive idea machine powered by the untapped market of non-tokenholder mindshare. This is made possible by novel monetization of the Nouns NFT's second onchain ledger: the delegation ledger.

As opposed to the standard ownership ledger, which tabulates token balances reflecting which address owns which token, Nouns voting power is tabulated by a separate delegation ledger which is generally less well-understood.

The delegation ledger manages onchain state of addresses' voting power without affecting the top-level ownership of the tokens themselves. Voting power is transferred between addresses entirely without needing tokens to change hands simply by delegating and undelegating from desired representatives. This is the ledger that the Nouns NFT relies on to distinguish which addresses are eligible to push an onchain proposal to Nouns governance for voting.

### For Nouns tokenholders: "LPs"

Are you looking to earn yield on your Nouns NFTs without giving up custody of your tokens? Rest assured you retain voting rights and can still participate in Nouns governance as usual.

Get started by [delegating and registering your tokens' voting power to Wave Protocol using the UI!](https://wave-monorepo-app.vercel.app/)

More information can be found in the [Protocol Participants Overview section of the Wave documentation](https://nouns-wave-protocol.vercel.app/src/overviews/Protocol-Participants-Overview.html)

### For Nouns builders: "Idea Creators"

Do you have an idea for a Nouns proposal and would like for your contribution to be voted on by the DAO in order to secure funding?

Get started by [minting an ERC1155 idea token to enter it into the current Wave and compete for sponsorships!](https://wave-monorepo-app.vercel.app/)

##### More information can be found in the [Protocol Participants Overview section of the Wave documentation](https://nouns-wave-protocol.vercel.app/src/overviews/Protocol-Participants-Overview.html)

### For Nouns community contributors: "Idea Sponsors"

Do you wish to financially support a pre-proposal idea and by extension its creator?

##### Get started with lobbying for ideas to become a proposal by [jumping directly into the app and sponsoring worthy ideas!](https://wave-monorepo-app.vercel.app/)

##### More information can be found in the [Protocol Participants Overview section of the Wave documentation](https://nouns-wave-protocol.vercel.app/src/overviews/Protocol-Participants-Overview.html)
