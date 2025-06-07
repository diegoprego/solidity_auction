// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Auction Smart Contract
/// @notice Auction with time extension, partial refunds, and automatic distribution of funds upon completion.
/// @dev Designed for testing or technical briefs. Refunds upon completion are executed directly from the contract.

contract Auction {
    // === Events ===
    event newBidAlert(address indexed sender, uint256 amountReceived);
    event auctionFinalizedAlert(address indexed winnerBidder, uint256 winnerBid);

    // === Public auction state ===
    uint256 public auctionStartTime;
    uint256 public auctionEndTime;

    address public owner;
    bool public withdrawalsAllowed = false;

    address public highestBidder;
    uint256 public highestBid;

    uint256 public accumulatedFees;

    // === Internal auction config ===
    uint256 internal initialDuration;
    uint256 internal extensionTime;
    uint256 internal thresholdTime;

    // === Bidder data ===
    struct Bidder {
        uint256 lastBid;
        uint256 cumulativeBids;
    }

    struct BidSummary {
        address addr;
        uint256 lastBid;
    }

    mapping(address => Bidder) internal bidders;
    mapping(address => bool) internal hasBid;
    address[] internal bidderAddresses;

    // === Constructor ===
    constructor(
        uint256 _initialDuration,
        uint256 _extensionTime,
        uint256 _thresholdTime
    ) {
        owner = msg.sender;
        auctionStartTime = block.timestamp;
        initialDuration = _initialDuration;
        auctionEndTime = auctionStartTime + _initialDuration;
        extensionTime = _extensionTime;
        thresholdTime = _thresholdTime;
    }

    // === Modifiers ===
    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this function.");
        _;
    }

    modifier onlyWhileActive() {
        require(!isInactive(), "The auction has ended");
        _;
    }

    modifier onlyWhileInactive() {
        require(isInactive(), "The auction has not yet ended");
        _;
    }

    // === Internal helper ===
    function isInactive() internal view returns (bool) {
        return block.timestamp > auctionEndTime;
    }

    // === View / public API ===
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function timeUntilInactive() external view returns (uint256) {
        if (isInactive()) {
            return 0;
        } else {
            return auctionEndTime - block.timestamp;
        }
    }

    function getBidders() external view returns (BidSummary[] memory) {
        uint256 length = bidderAddresses.length;
        BidSummary[] memory result = new BidSummary[](length);

        for (uint256 i = 0; i < length; i++) {
            address addr = bidderAddresses[i];
            result[i] = BidSummary({
                addr: addr,
                lastBid: bidders[addr].lastBid
            });
        }

        return result;
    }

    /// @notice Returns the address of the auction winner and the amount of their winning bid.
    /// @dev Can be called at any time, but makes sense after the auction has ended.
    /// @return winner Address of the highest bidder.
    /// @return amount Amount bid by the winner.

    function getWinner() external view returns (address winner, uint256 amount) {
        return (highestBidder, highestBid);
    }

    // === Auction core ===

    function newBid() external payable onlyWhileActive {
        require(msg.sender != highestBidder, "Your current offer has not yet been surpassed.");
        require(msg.value > highestBid * 105 / 100, "Your offer must be 5% higher than the last offer");

        uint256 amount = msg.value;

        if (!hasBid[msg.sender]) {
            hasBid[msg.sender] = true;
            bidderAddresses.push(msg.sender);
        }

        bidders[msg.sender].lastBid = amount;
        bidders[msg.sender].cumulativeBids += amount;

        highestBid = amount;
        highestBidder = msg.sender;

        emit newBidAlert(msg.sender, amount);

        if (block.timestamp >= auctionEndTime - thresholdTime) {
            auctionEndTime += extensionTime;
        }
    }

    /// @notice Allows a bidder to withdraw excess funds from bids prior to the last one.
    /// @dev Can only be called once per bid. A 2% fee applies.

    function partialWwithdrawal() external onlyWhileActive {
        Bidder storage bidder = bidders[msg.sender];

        require(bidder.lastBid != 0, "You have no registered offers");

        uint256 amount = bidder.cumulativeBids - bidder.lastBid;
        require(amount > 0, "You have no partial funds to withdraw");

        uint256 fee = amount * 2 / 100;
        uint256 payout = amount - fee;
        accumulatedFees += fee;

        bidder.cumulativeBids = bidder.lastBid;

        (bool success, ) = msg.sender.call{value: payout}("");
        require(success, "Fund transfer failed");
    }

    // === Auction finalization and auto-distribution ===

    /// @notice Closes the auction and automatically transfers refundable funds to each bidder.
    /// @dev Applies a 2% fee to each transfer. The winner does not receive their last bid.
    /// Only the owner can execute it. Sets `withdrawalsAllowed = true`. Emits `auctionFinalizedAlert`.
        
    function closeAuctionAndDistributeFunds() external onlyOwner onlyWhileInactive {
        require(!withdrawalsAllowed, "The funds have already been distributed");
        withdrawalsAllowed = true;

        emit auctionFinalizedAlert(highestBidder, highestBid);

        for (uint256 i = 0; i < bidderAddresses.length; i++) {
            address addr = bidderAddresses[i];
            Bidder storage b = bidders[addr];

            uint256 refund = addr == highestBidder
                ? (b.cumulativeBids - b.lastBid)
                : b.cumulativeBids;

            if (refund > 0) {
                uint256 fee = refund * 2 / 100;
                uint256 payout = refund - fee;
                accumulatedFees += fee;

                (bool success, ) = payable(addr).call{value: payout}("");
                require(success, "Failed to send funds to bidder");
            }
        }
    }

    // === Owner-only withdrawals ===

    /// @notice Allows the owner to withdraw the winning bid after the auction closes.
    /// @dev Only available once and only if the funds have already been distributed.

    function ownerWithraw() external onlyOwner onlyWhileInactive {
        require(withdrawalsAllowed, "You must first close the auction and distribute funds.");

        uint256 amount = highestBid;
        require(amount > 0, "Funds already withdrawn");

        highestBid = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Failed to send funds to the owner");
    }

    /// @notice Allows the owner to withdraw accrued fees (2% of each partial withdrawal or final distribution).
    /// @dev Resets `accumulatedFees` after withdrawal.

    function withdrawFees() external onlyOwner {
        uint256 amount = accumulatedFees;
        require(amount > 0, "There are no accumulated fees");

        accumulatedFees = 0;

        (bool success, ) = payable(owner).call{value: amount}("");
        require(success, "Fees withdrawal failure");
    }
}
