# Voting while delegated to Wave Protocol

### Because Wave Protocol is noncustodial and registers delegations using optimistic state, Nouns NFT holders who have delegated their voting power to Wave Protocol retain the right to vote and participate in the Nouns governance ecosystem at all times.

### Important note: voting on Nouns proposals uses a checkpointing system, restricting votes to the voting power of each account **when the proposal goes live**! In order to vote you must be on top of the proposal's lifecycle and complete step 1 and 2 during the proposal's "Pending" state prior to the proposal going live for public voting.

## To vote while delegated to Wave

Voting and participating while delegated to Wave comprises four major steps, three of which require sending an onchain transaction:

- Write down your Wave delegate's address as you will need it in the third step when redelegating to Wave. The address may be fetched from the Wave Core contract or Nouns Token contract.
- Delegate to yourself to reclaim your voting power. This undelegates from Wave Protocol
- Vote on the proposal(s) you're interested in, provided you met the time constraints noted above
- Redelegate to your Wave delegate (which you wrote down) before the completion of the current Wave

That's it! Profit :)

### 1. Fetching your Wave delegate's address

In order for Wave Protocol to guarantee your expected yield, you should record your delegate address and redelegate to the same delegate after voting. This can be done in multiple ways:

If you know your Delegate's address, write it down and move to step 2.
If you know your Delegate's ID but not its address, call `Wave::getDelegateAddress(<delegateID>)` on the [Wave core contract.](https://etherscan.io/address/0x00000000008DDB753b2dfD31e7127f4094CE5630)
If you don't know your Delegate's address or ID, check what delegate address you are currently delegated to by calling `NounsToken::delegates(<yourAddress>)` on the [Nouns token contract](https://etherscan.io/address/0x9C8fF314C9Bc7F6e59A9d9225Fb22946427eDC03).

Be sure to record your Wave delegate address so that you can redelegate to it after voting.

##### While this step is technically not necessary due to Wave Protocol's matchmaking mechanism, onchain state may change during the interim while you are delegated to yourself and voting. In certain cases this can lead to the protocol UI suggesting a different delegate ID for you when redelegating. In such a case, if your voting power is below the current minimum required votes to push a proposal (ie your voting power is considered a "partial" delegation in need of matchmaking), your yield is no longer guaranteed and may be dependent on the protocol finding another match for your liquidity.

### 2. Delegate to yourself

It is recommended to use the Nouns governance UI to redelegate your voting power to yourself (and away from Wave Protocol). Should the UI be unavailable for some reason, this can also be done at the contract level using `NounsToken::delegate(<yourAddress>)`

### 3. Vote on proposals

It is likewise recommended to use the Nouns governance UI to vote on the proposals you feel strongly about. Again, should the UI be unavailable for some reason, this can also be done at the contract level using `NounsToken::castVote()` or some variation thereof (refundable, with reason, etc)

### 4. Redelegating to Wave Protocol

Simply redelegate to the Delegate address that you wrote down (and had been delegated to previously before voting). This must be done on the Nouns Token contract either using the Nouns governance UI or with `NounsToken::delegate(delegateAddress)` Since your original delegation to Wave included registering an optimistic delegation in the Wave core contract's storage, there is no need to re-register or further interact with Wave Protocol contracts.
