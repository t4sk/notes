# Insurance

A staking protocol where stakers earn yield in exchange for providing collateral coverage to an insuree.

## Overview

- **Insuree** deposits reward tokens and sets an emission rate for the duration
- **Stakers** deposit tokens to earn a share of those rewards
- The stakers' deposits act as collateral — if a claim is made, staked tokens can be transferred to the insuree
- **WithdrawDelay** wraps staking withdrawals with a time lock so collateral remains available when needed

## Contracts

### Factory

Deploys a matched `Stake` + `WithdrawDelay` pair and wires them together. The caller becomes the initial auth on both contracts.

```
Factory.create(token, insuree, dur, dust, cov, epoch)
  └─► Stake
  └─► WithdrawDelay
```

### Stake

Stakers deposit tokens and earn rewards proportional to their share. The insuree funds the reward pool via `inc()` and may extend it with `roll()`.

**Reward cap** — rewards paid to stakers over a duration are capped at `total_staked / cov`. Excess accumulates in `keep` and is reclaimed by the insuree via `refund()`.

**State machine:**

```
        stop()
Live ──────────► Stopped
                    │
           ┌────────┴────────┐
      settle(Cover)    settle(Exit)
           │                 │
           ▼                 ▼
         Cover             Exit
```

| State   | Description                                     |
| ------- | ----------------------------------------------- |
| Live    | Normal operation — deposit, earn, withdraw      |
| Stopped | Emissions halted, settlement pending            |
| Cover   | Claim paid — staked tokens sent to insuree      |
| Exit    | No claim — stakers withdraw principal + rewards |

**Key functions:**

| Function          | Caller  | Description                                          |
| ----------------- | ------- | ---------------------------------------------------- |
| `inc(amt)`        | anyone  | Add tokens to the reward pool, increase rate         |
| `roll(r)`         | insuree | Schedule next-period rate in the last half of `dur`  |
| `deposit(amt)`    | staker  | Stake tokens                                         |
| `take()`          | staker  | Claim accrued rewards                                |
| `restake()`       | staker  | Compound rewards back into stake                     |
| `stop()`          | auth    | Halt emissions, snapshot keep                        |
| `settle(s)`       | auth    | Transition to Cover or Exit                          |
| `cover(dst, amt)` | auth    | Transfer staked collateral to insuree                |
| `exit()`          | staker  | Withdraw principal + rewards (Exit state or expired) |
| `refund()`        | insuree | Reclaim uncapped rewards and keep                    |

### WithdrawDelay

Wraps `Stake.withdraw()` with a two-epoch delay. Queued tokens remain in scope for a claim until the delay expires.

**Epoch buckets** — `stop()` snapshots `dumped`: the total queued within the most recent two epochs. These tokens are exposed to a claim because they were withdrawn while cover was still active.

**State machine:**

```
        stop()
Live ──────────► Stopped
                    │
           ┌────────┴────────┐
         cover()          refill()
           │                 │
           ▼                 ▼
        Covered           Refilled
```

| State    | `unlock()` behaviour                                          |
| -------- | ------------------------------------------------------------- |
| Live     | Unlockable after lock expiry (`curr + 2 * EPOCH`)             |
| Stopped  | Unlockable if lock predates stop epoch, or nothing was dumped |
| Covered  | Only pre-stop locks unlockable (`lock.exp <= last`)           |
| Refilled | All locks immediately unlockable                              |

**Key functions:**

| Function     | Caller | Description                                         |
| ------------ | ------ | --------------------------------------------------- |
| `queue(amt)` | staker | Withdraw from Stake into a time-locked position     |
| `unlock(i)`  | staker | Claim a matured lock                                |
| `stop()`     | auth   | Freeze queuing, snapshot dumped amount              |
| `cover(dst)` | auth   | Forward `dumped` tokens to Stake for the insuree    |
| `refill()`   | auth   | Clear dump, allow all stakers to unlock immediately |

## Lifecycle

### Normal expiry

```
Insuree   inc() ──────────────────────────────────── refund()
                                                          ▲
Stakers   deposit() ──► take()/restake() ──► exit() ─────┘
```

The insuree funds rewards over `dur`. At expiry stakers call `exit()`. The insuree reclaims uncapped excess via `refund()`.

### Claim (Cover path)

```
Insuree   inc() ──────────────────────────── (claim event)
                                                    │
Auth      Stake.stop()                              │
          Stake.settle(Cover)                       │
          WithdrawDelay.stop()                      │
          WithdrawDelay.cover(dst) ────────────────►┘  dumped tokens → insuree

Stakers   deposit() ──► queue() ──► unlock()  (pre-stop locks only)
```

1. Auth halts emissions: `Stake.stop()` + `WithdrawDelay.stop()` — `dumped` is snapshotted
2. Auth settles: `Stake.settle(Cover)` + `WithdrawDelay.cover(dst)` — dumped tokens flow through `Stake.cover()` to the insuree
3. Stakers with locks older than the stop epoch can `unlock()`; recent locks (within the two-epoch window) cannot

### No-claim (Exit / Refill path)

```
Auth      Stake.stop() ──► Stake.settle(Exit) ──► WithdrawDelay.refill()

Stakers   exit()    (principal + rewards)
          unlock()  (all queued positions)
```

No claim. All stakers recover principal and earned rewards. All WithdrawDelay locks become immediately unlockable.

## Reward accounting

```
topped  total tokens deposited as rewards (inc + roll)
paid    rewards transferred out (take, restake, exit, refund)
keep    cap savings + pot captured at stop

invariants:
  topped >= paid
  bal(Stake) >= total + topped - paid
  bal(Stake) >= total + pot + calc(all stakers)
```

The reward cap ensures `rewards_to_stakers <= total_staked / cov` over any duration, guaranteeing the insuree minimum coverage relative to rewards paid out.

## Deployed contracts

```
address constant TOKEN =0xb45d2DA802eD4848A1A25755802c26303f0334e2
address constant FACTORY = 0x8aa77Cb43B32f0A0ab34a1C13d20114d36200383
address constant STAKE = 0x072090976ba290695c9871910317AC1B7d924Bb0
address constant WITHDRAW_DELAY = 0x935CF6E1854539D81ac4350eA8EBe3B7ED65d1CB
```

## Improvements

- Continuous (expires after last `inc` + `dur`)
- Insuree vault
