# Overview

TODO
Nouns NFT holders earn yield in exchange for lending their tokens' proposal power to Wave Protocol, which grants Wave Protocol
democratizes access and lowers the barrier of entry for anyone with a worthy idea,

## Wave Core

###

The Wave Protocol Core contract manages a set of deterministic Delegate contracts whose sole purpose
is to noncustodially receive delegation from Noun token holders who wish to earn yield in exchange for granting
Wave the ability to push onchain proposals to the Nouns governance ecosystem. Winning proposals are chosen
via a permissionless ERC115 mint managed by the Wave IdeaHub contract.

Since Nouns voting power delegation is all-or-nothing on an address basis, Nounders can only delegate
(and earn yield) on Nouns token balances up to the proposal threshold per wallet address.

## IdeaTokenHub

### A hub of ERC1155 tokens representing Nouns Governance ideas

The Wave Protocol Idea Token Hub extends the Nouns governance ecosystem by tokenizing and crowdfunding ideas for Nouns governance proposals. represented as an ERC1155 tokenId.
Use of ERC1155 enables permissionless onchain minting with competition introduced by a crowdfunding auction.
Each `tokenId` represents a proposal idea which can be individually funded via permissionless mint. At the conclusion
of each auction, the winning tokenized ideas (with the most funding) are officially proposed into the Nouns governance system
via the use of lent Nouns proposal power, provided by token holders who have delegated to the protocol.
