Here’s a clear README for your Commit–Reveal Raffle contract:

---

# Commit-Reveal Raffle Smart Contract

## Overview

This smart contract implements a **deterministic, fair raffle system** using a **commit–reveal scheme**.
It does **not** generate randomness on-chain; instead, the fairness can be **verified off-chain** using the committed hashes and revealed seeds.
The contract only handles **ticket accounting** — no prize distribution or randomness logic is on-chain.

---

## Key Features

* **Raffle Creation**: Organizers can set up raffles with ticket prices, maximum winners, and commit/reveal phases.
* **Ticket Purchase**: Participants can buy tickets during the commit phase; pricing is enforced.
* **Commit–Reveal Mechanism**:

  * **Commit Phase**: Players submit a hash of their secret seed.
  * **Reveal Phase**: Players reveal their seed, which can be checked off-chain to match the commit.
* **Deterministic Fairness**: The final winner selection is verifiable externally.
* **Organizers Close Raffles**: Once reveal phase ends, the organizer closes the raffle.

---

## Data Structures

### `raffles`

Stores raffle configuration.

```clarity
{
  organizer: principal,
  name: (string-ascii 80),
  ticket-price: uint,
  max-winners: uint,
  commit-end: uint,
  reveal-end: uint,
  status: uint ;; 1=open, 2=closed
}
```

### `tickets`

Tracks ticket ownership per buyer in each raffle.

```clarity
{
  tickets: uint,
  spent: uint,
  last-update: uint
}
```

### `commits`

Holds commit hashes and revealed seeds for verification.

```clarity
{
  commit-hash: (string-ascii 64),
  revealed-seed: (optional (string-ascii 64))
}
```

---

## Public Functions

### `create-raffle`

```clarity
(create-raffle name ticket-price max-winners commit-end reveal-end)  
```

* Creates a new raffle.
* Validates that times and parameters are correct.
* Returns raffle ID.

### `buy-tickets`

```clarity
(buy-tickets raffle-id ticket-count spend)  
```

* Purchases tickets during commit phase.
* Validates price (`spend = ticket-count × ticket-price`).

### `commit-seed`

```clarity
(commit-seed raffle-id commit-hash)  
```

* Stores commitment hash during commit phase.
* Commit hash should be SHA256(seed + salt) or similar (verified off-chain).

### `reveal-seed`

```clarity
(reveal-seed raffle-id seed)  
```

* Reveals the seed during the reveal phase.
* Stores the seed for off-chain verification.

### `close`

```clarity
(close raffle-id)  
```

* Organizer closes raffle after reveal phase ends.

---

## Read-Only Functions

* `get-raffle(raffle-id)` → Returns raffle details.
* `get-commit(raffle-id, committer)` → Returns commit and revealed seed.
* `get-tickets(raffle-id, buyer)` → Returns ticket details for buyer.

---

## Commit–Reveal Flow

1. **Raffle Created** by organizer.
2. **Commit Phase** (until `commit-end`):

   * Participants buy tickets.
   * Participants commit by submitting hash of their seed.
3. **Reveal Phase** (`commit-end` < block ≤ `reveal-end`):

   * Participants reveal their seed.
4. **Close Raffle** after `reveal-end`.
5. **Winner Selection** is done off-chain using all revealed seeds and ticket data.

---

## Error Codes

| Code   | Meaning                  |
| ------ | ------------------------ |
| `u600` | Invalid parameters       |
| `u601` | Raffle not found         |
| `u602` | Invalid status or timing |
| `u603` | Unauthorized action      |

---

## Notes

* **No randomness is generated on-chain**. All winner determination logic happens off-chain.
* Commit–reveal ensures participants cannot change seeds after commit phase ends.
* Any participant failing to reveal forfeits their chance to influence results.

