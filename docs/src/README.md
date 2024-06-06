<div align="center" style="font-size: 2em;">

# Wave Protocol

</div>

Wave Protocol is an onchain crowdfunding system built upon the Nouns Governance ecosystem to permissionlessly and meritocratically democratize access to Nouns contributions in the form of proposals.

At its heart, the protocol offers Nouns governance proposals as a service to the Nouns peripheral community who may not be capitalized enough to afford the 2 Nouns NFTs required to push their proposal onchain. The result is democratization of access to the Nouns sphere by lowering the barrier of entry for anyone with a worthy idea and desire to contribute.

The protocol makes use of currently unproductive Nouns token voting power to engender a competitive idea machine powered by the untapped market of non-tokenholder mindshare.

Economic incentives for each type of protocol participant (Nounders, Idea Creators, and Sponsors) are aligned by compensating Nouns token delegators with yield, granting Idea Creators competitive access to pushing Nouns proposals onchain, and Idea Sponsors with scouting provenance and lobbying opportunities.

## Table of Contents

- [Wave Protocol](#wave-protocol)
  - [Table of Contents](#table-of-contents)
  - [Protocol Overview](#protocol-overview)
  - [Security Considerations](#security-considerations)
  - [Why extend Nouns governance?](#why-extend-nouns-governance)
  - [To run fuzz tests](#to-run-fuzz-tests)
  - [Live Deployments](#live-deployments)

## Protocol Overview

Wave Protocol accepts Nouns token voting power noncustodially via delegation, leveraging optimistic state to compensate registered Noun delegators with yield in exchange for delegating their voting power. The yield comprises the total funds raised by each Wave's winning ideas, which are represented as ERC1155 tokens.

Idea tokens that amass the highest capital from Sponsors are selected as winners at the conclusion of each Wave, the crowdfunding period during which ideas can be created and sponsored. The Wave Core contract determines the number of winning ideas per Wave and validates optimistic state at finalization based on its available "liquidity" (ie voting power) which it uses to push onchain proposals to the Nouns Governor.

## Security Considerations

To run, Wave Protocol is designed to require only noncustodial delegation of the Nouns token's `ERC721CheckPointable` voting power ledger, which is entirely separate from the token's ownership ledger. As a result, Wave Protocol _never_ requires Nouns token approvals, transfers, or custody of any kind.

To provide voting power "liquidity" in exchange for yield, Nounder token holders need only lend their voting power by delegating and registering using the Wave UI and can rest assured that Wave Protocol does not ever touch the Nouns token's custodial ledger.

## Why extend Nouns governance?

The Wave protocol introduces numerous benefits to all parties involved. It provides Nouns NFT holders with a way to earn yield on their Nouns tokens by noncustodially lending their voting power to the Wave protocol via delegation. Delegating to Wave thereby extends the right to make onchain proposals to addresses that don't hold Nouns tokens but would like to submit proposal ideas.

## To run fuzz tests

```shell
$ forge test
```

## Live Deployments

Wave protocol is currently deployed in Beta on Base Sepolia testnet for backend & frontend development and finalized Ethereum mainnet deployments are coming soon.

| Name         | Contract Details | Contract Address                           |
| ------------ | ---------------- | ------------------------------------------ |
| IdeaTokenHub | Harness, Proxy   | 0x54a488958D1f7e90aC1a9C7eE5a450d1E2170789 |
| Wave         | Harness, Proxy   | 0x55C7c4ADEd315FF29a336cAE5671a4B0A69ae348 |
| NounsToken   | Harness          | 0xa28Fb072290d6d731cA08EFb8f79bF4dB1D13e67 |

Note that the above testnet contracts deployed to Base Sepolia network are harnesses to expose convenience functions that would normally otherwise be protected to expedite development.
