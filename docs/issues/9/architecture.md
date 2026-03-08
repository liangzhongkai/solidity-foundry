# Issue #9 Architecture Digest

## Why This Diagram Exists

- SimpleLottery adds a new standalone contract with create/purchase/claim/refund flow.
- Reviewer should understand state transitions and blockhash-based randomness before reading code.

## System View

```mermaid
flowchart TD
    subgraph Create["createLottery"]
        A[User] -->|createLottery| B[SimpleLottery]
        B -->|store purchaseDeadline, drawBlock| S[(Lottery struct)]
    end

    subgraph Purchase["purchaseTicket (24h window)"]
        A2[User] -->|0.01 ether + lotteryId| B
        B -->|block.timestamp < purchaseDeadline| S
        B -->|push participant, ticketCount++| S
    end

    subgraph Claim["claimWinnings (drawBlock+1 .. drawBlock+256)"]
        A3[Winner] -->|claimWinnings| B
        B -->|blockhash drawBlock % ticketCount| W[winner index]
        B -->|transfer pool| A3
    end

    subgraph Refund["refund (after drawBlock+256, no claim)"]
        A4[Participant] -->|refund| B
        B -->|block.number > drawBlock+256| S
        B -->|transfer ticket cost| A4
    end

    Create --> Purchase
    Purchase --> Claim
    Purchase --> Refund
```

## Data And Control Flow Notes

- **State**: `lotteries[lotteryId]` holds purchaseDeadline, drawBlock, participants[], ticketCount, winner, winnerClaimed.
- **Permission**: Any address can create, purchase, claim (if winner), refund (if past lookback).
- **External**: ETH transfers via `call{value}`; ReentrancyGuard protects claim/refund.
- **Invariants**: blockhash(drawBlock) only available when block.number > drawBlock; claim window = [drawBlock+1, drawBlock+256].

## Review Hotspots

- `claimWinnings`: blockhash lookup, winner selection, transfer.
- `refund`: _removeParticipant swap-with-last logic, ticketCount decrement.
- `test/15-simple-lottery/SimpleLottery.t.sol`: vm.roll for block advancement, blockhash availability.
