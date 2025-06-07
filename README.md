# Auction Smart Contract

This smart contract implements an auction with automatic time extension and automatic fund distribution logic upon completion. It was designed to meet a technical requirement, so some features (such as partial withdrawal) are for evaluation purposes rather than production purposes.

---

## General flow

1. **Start**: The auction starts automatically when the contract is deployed.
2. **Bids (`newBid`)**: Users can bid if they exceed the current bid by at least 5%. If a bid is placed within a configurable threshold time (`thresholdTime`), the auction is automatically extended.
3. **Partial Withdrawal**: Allows users to recover excess deposited funds from offers prior to the most recent one. This can only be called once per offer.
4. **Close and distribute (`closeAuctionAndDistributeFunds`): When the auction ends, the owner can close the auction and automatically send the funds to each bidder.
5. **Owner withdraw (`ownerWithraw`): The owner can withdraw the winning bid once the remainder has been distributed.
6. **Fees (`withdrawFees`): The contract charges a 2% fee on each withdrawal (partial or final), and the owner can withdraw them.

---

## Roles

- **owner**: User who deploys the contract, can close the auction, and withdraw funds.
- **bidders**: Any address that places a valid bid.

---

## Main Features

### `newBid() payable`
Allows a new bid to be placed, exceeding the current bid by at least 5%. Extends the bid time if placed in the final minutes of the auction.

### `partialWithdrawal()`
Allows a user to withdraw funds deposited in bids prior to the last bid. It can only be called once per bidding cycle. A 2% fee applies.

### `closeAuctionAndDistributeFunds()`
Can only be executed by the owner after the auction ends. Automatically sends available funds to each user, retaining the 2% fee. No user interaction is required to recover their money.

### `ownerWithraw()`
Allows the owner to withdraw the amount corresponding to the winning bid (`highestBid`) after closing and distribution.

### `withdrawFees()`
Allows the owner to withdraw accrued fees (2%).

---

## Query Functions

- `getBidders()` – Returns the last bid for each bidder.
- `getWinner()` – Returns the address of the winning bidder and the amount of their highest bid.
- `getBalance()` – Returns the contract balance.
- `timeUntilInactive()` – Returns the time remaining until the auction ends.

---

## Considerations

- Bids are only accepted via the `newBid()` function. Sending ETH directly to the contract is not permitted.
- Refunds at the end of the auction are automatically distributed by the contract, without requiring users to claim them.
- The contract does not provide manual withdrawal capabilities for users after the contract closes.
- A 2% fee is charged on withdrawals (partial or final), which remains available to the owner.

---

## Test Mode

This contract was designed for technical evaluation purposes. Restart flow or multiple rounds are not included, but can be added with additional features.

## Functions Excluded Due to Deposit Requirements

In order to improve the security and control of financial flows, the following functions and structures were originally designed, but were intentionally removed to meet the requirements of the practical work:

- mapping(address => uint256) pendingWithdrawals: This was to be used to securely store each user's available withdrawal balances after the auction closes.
- withdrawAll(): This function was designed to allow users to manually withdraw their funds once withdrawals were enabled by the owner.
- Dependencies on pendingWithdrawals[msg.sender]: All logic associated with the accumulation, control, and withdrawal of individual funds was removed to comply with the automatic distribution requirement controlled solely by the owner.

These functions were replaced by the current closeAuctionAndDistributeFunds() logic, which automatically transfers funds to eligible bidders, applying fees and avoiding subsequent user interaction.

---

## License

MIT
