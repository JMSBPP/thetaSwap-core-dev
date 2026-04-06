# Range Accrual Note (VANILLA) — Design Specification

**Date**: 2026-04-06
**Branch**: `0-0-0-9-algebra-integration` (will move to dedicated branch)
**Status**: Design approved, pending implementation plan
**Upstream**: Range Accrual Notes theory (`~/learning/cfmm-theory/lp-derivatives/notes/RANGE_ACCRUAL_NOTES/`)

---

## 1. Product Definition

### What It Is

A protocol-agnostic ERC-1155 token that represents a transferable claim on the **theta component** (fee/reward accumulation) of a liquidity position within a specific price range and epoch. The token extends and standardizes Angstrom's `GrowthOutsideUpdater` accumulator pattern into a tradable instrument compatible with any DEX or marketplace.

### Decomposition Context

```
LP Position = Delta (directional/IL) + Gamma (LVR/adverse selection) + Theta (fee income)
                    │                         │                            │
                    ▼                         ▼                            ▼
              Panoptic decomposes      Milionis LVR captures        RangeAccrualNote
              via isLong=0/1           (Angstrom auctions)          tokenizes THIS
```

Panoptic decomposes delta into tradeable options. Angstrom captures gamma via auction bids. **No instrument yet exists that tokenizes the theta residual.** The Range Accrual Note fills this gap.

### Product Hierarchy

```
Layer 0:  LP position (fee-generating, on V3/V4/Angstrom/Algebra)
Layer 1:  RangeAccrualNote tokenizes theta from Layer 0
Layer 2:  Fee-income index = observable built from Layer 1 settlements
Layer 3:  DataSwap / FCI index = user-defined indexes on top of Layer 2
```

### Theoretical Foundations

| Paper | Key Result Used |
|-------|----------------|
| Pap (2022) "Pricing Range Accrual Products" | RAN = sum of digital options with delayed payoff (Eq. 4.12). Multi-period extension (Eq. 4.13). Time-dependent BS and Heston pricing. |
| Panoptic / Kristensen (2024) | No BS oracle needed. `dFee/dt = σ²S²L / (2·width)` converges to BS theta. Streaming premium via accumulators. VEGOID spread control. |
| Bichuch & Feinstein (2025) "Price of Liquidity" | Implied fee rate = LVR-based break-even fee. Fixed-for-floating fee swap. LVR ≈ 0.97× fees over 30-day windows. |
| Capponi & Zhu (2024) "Optimal Exiting for LP" | Expiration = first passage time through price boundaries. Range width determines expected lifetime. `p*_U` increases in φ, decreases in μ,σ. |
| Milionis et al. (2022) "AMM and LVR" | `LVR ~ σ²·L·dt`. Angstrom bid ≈ realized LVR per block. σ²_realized ≈ bid/(L·dt). |
| FLAIR — Milionis, Wan, Adams (2023) | LP competitiveness via fee concentration. HHI-based fairness metric. |
| Ma & Crapis (2024) "Cost of Permissionless Liquidity" | Cost framework for LP participation under adverse selection. |

---

## 2. Architecture

### Core Principle: Maximum Modularity

The note is a standalone token + interface. Not tied to any specific AMM protocol, vault, or counterparty matching engine. It can be traded on any DEX, wrapped by any vault, or paired in any derivative overlay.

### Three-Layer Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Protocol Layer (read-only adapters, no state)          │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │AngstromReader│  │  V3Reader    │  │  V4Reader    │  │
│  │(GrowthOutside│  │(FeesCalc.sol │  │(StateLibrary)│  │
│  │ Updater math)│  │  pattern)    │  │              │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         └────────────┬─────┘────────────────┘           │
│                      ▼                                  │
│         ┌────────────────────────┐                      │
│         │  IAccumulatorSource    │  ← standard interface │
│         │  growthInside(pool,    │                      │
│         │    tickLower,tickUpper)│                      │
│         │  globalGrowth(pool)    │                      │
│         │  epochOf(blockNumber)  │                      │
│         └────────────┬───────────┘                      │
└──────────────────────┼──────────────────────────────────┘
                       │
┌──────────────────────┼──────────────────────────────────┐
│  Token Layer         ▼                                  │
│  ┌──────────────────────────────────────────────┐       │
│  │  RangeAccrualNote (ERC-1155 Minimal base)    │       │
│  │                                              │       │
│  │  Storage (per tokenId):                      │       │
│  │    entryGrowthInside  (snapshot at mint)     │       │
│  │    entryGlobalGrowth  (for n/N ratio)        │       │
│  │    totalLiquidity     (units minted)          │       │
│  │                                              │       │
│  │  Premium tracking (SFPM pattern):            │       │
│  │    s_accountPremiumOwed[tokenId][holder]      │       │
│  │    s_accountPremiumGross[tokenId]             │       │
│  │    spread = f(VEGOID_equivalent)              │       │
│  └──────────────────────────────────────────────┘       │
│                                                         │
│  ┌──────────────────────────────────────────────┐       │
│  │  CollateralManager (Panoptic CT pattern)     │       │
│  │  - requiredCollateral(tokenId, isLong)        │       │
│  │  - deposit / withdraw                         │       │
│  │  - liquidation threshold                      │       │
│  └──────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────┘
```

---

## 3. Token Design

### Standard: ERC-1155 with Epoch-Batched Fungibility

**tokenId encoding:**

```
tokenId = keccak256(abi.encode(
    accumulatorSource,   // address — which protocol adapter
    poolId,              // bytes32 — pool identifier
    tickLower,           // int24
    tickUpper,           // int24
    epochId              // uint40 — epoch number
))
```

- **Fungible within**: same (source, pool, range, epoch) tuple
- **Non-fungible across**: different epochs or different ranges
- **Base implementation**: Panoptic's `ERC1155Minimal.sol`
- **Encoding utilities**: Panoptic's `LiquidityChunk.sol` for packing range + liquidity

### Lifecycle

```
MINT                           ACCRUE                          SETTLE
─────                          ──────                          ──────
mint(source, pool, tL, tU)     Each block where                claim(tokenId):
  │                            tick ∈ [tL, tU]:                  │
  ├─ Both sides deposit          growthInside increments         ├─ Read current
  │  collateral (CT pattern)     by reward/fee per L             │  accumulator delta
  │                                                              │
  ├─ Snapshot:                 Each block where                  ├─ Compute premium
  │  entryGrowthInside         tick ∉ [tL, tU]:                  │  via SFPM pattern
  │  entryGlobalGrowth           growthInside stays flat         │  (owed vs gross)
  │                              (zero accrual)                  │
  └─ Mint ERC-1155 tokens                                       ├─ Apply spread
     to long holder                                             │  (VEGOID equivalent)
                                                                │
                                                                └─ Transfer payout
                                                                   + return collateral
```

### No Fixed Coupon (Panoptic Self-Pricing)

The note has **no fixed coupon parameter**. Instead:

- The **value** = `growthInside(now) - growthInside(epochStart)` per unit of liquidity
- This delta grows as fees/rewards accrue while price is in range
- The pool's fee accumulation IS the pricing oracle (Panoptic convergence)
- When the note trades on a secondary market, the market price reveals the implied coupon rate
- No off-chain calibration, no BS oracle, no vol input needed

**Premium streaming** follows Panoptic's SFPM pattern:

```
premiumBase = collected * totalLiquidity / netLiquidity²
premiumOwed = premiumBase * (net + removed/VEGOID) / total
```

**Variable mapping to RAN context:**

| SFPM Variable | RAN Meaning | Source |
|---------------|-------------|--------|
| `collected` | `growthInside_delta * positionLiquidity` — realized fee/reward income for this position since last touch | `IAccumulatorSource.growthInside()` delta |
| `totalLiquidity` | Sum of all liquidity units minted for this tokenId (all holders) | `RangeAccrualNote` storage |
| `netLiquidity` | `totalLiquidity - removedLiquidity` — liquidity currently active (not burned/exited) | `RangeAccrualNote` storage |
| `removed` | Liquidity units that have been burned but whose premium hasn't fully settled | `RangeAccrualNote` storage |
| `net` | Same as `netLiquidity` | Alias |
| `total` | Same as `totalLiquidity` | Alias |
| `VEGOID` | Spread parameter controlling premium compression between long/short sides. Higher VEGOID = tighter spread. Governance-settable. | Configuration parameter |

Where VEGOID_equivalent controls the spread between what short sellers earn and long holders pay.

---

## 4. Time Model: Range-as-Maturity

### No Calendar Expiry

The note has no fixed maturity T. Instead, per Capponi-Zhu (2024):

- The **range [tickLower, tickUpper]** defines the effective maturity via first passage time
- Expected lifetime: `E[τ] = f(σ, μ, range_width)` — wider range → longer expected time in range
- While price is in range: theta accrues at rate `≈ σ²S²L / (2·width)` (Panoptic)
- When price exits: accrual stops. This is the economic "expiration"

### Epoch Checkpoints (Not Expiration)

Epochs serve as **settlement checkpoints**, not maturity:

- Each epoch (configurable: hourly, daily) is a coupon determination period
- At epoch boundaries, accumulated theta can be claimed
- Notes auto-roll into the next epoch unless the holder exits
- Epoch infrastructure reuses the existing FCI V2 epoch snapshot system

### Observation Granularity (Two-Scale)

Mirrors the existing FCI architecture:

- **Block-level**: Accumulator increments per block (captures JIT dynamics at 1-3 blocks)
- **Epoch-level**: Settlement/claim windows (position lifetime in hours/days)
- Pap's `n/N` ratio maps to: `n` = blocks where tick was in range, `N` = total blocks in epoch

---

## 5. Protocol Adapter Interface

### `IAccumulatorSource`

The standard interface that abstracts accumulator reads across protocols:

```
interface IAccumulatorSource {
    /// @notice Returns the accumulated growth inside a tick range, packed as LeftRight
    /// @dev Returns int256 packed via LeftRight.sol: left half = token0 growth, right half = token1 growth
    /// For single-token accumulators (e.g., Angstrom bid_in_asset0), token1 slot is zero.
    /// Handles all three tick-position cases internally:
    ///   - current_tick < tickLower:  outsideBelow[lower] - outsideAbove[upper]
    ///   - current_tick in [lower, upper): globalGrowth - outsideBelow[lower] - outsideAbove[upper]
    ///   - current_tick >= upper: outsideAbove[upper] - outsideBelow[lower]
    function growthInside(
        bytes32 poolId,
        int24 tickLower,
        int24 tickUpper
    ) external view returns (int256);

    /// @notice Returns the global cumulative growth, packed as LeftRight
    function globalGrowth(bytes32 poolId) external view returns (int256);

    /// @notice Returns the current epoch number for a given timestamp
    /// @dev Uses timestamp (not block number) to match FCI V2 epoch storage convention
    function epochOf(uint256 timestamp) external view returns (uint40);

    /// @notice Returns the epoch length in seconds
    function epochLength() external view returns (uint256);
}
```

### Fee Growth Scalar Convention

The `growthInside` and `globalGrowth` return values use Panoptic's `LeftRight.sol` packing:
- **Left 128 bits** (`int128`): token0 fee/reward growth per unit liquidity
- **Right 128 bits** (`int128`): token1 fee/reward growth per unit liquidity

This handles protocol differences:
- **Angstrom**: `bid_in_asset0` maps to token0 (left); token1 is zero
- **V3/V4**: Both `feeGrowthInside0X128` and `feeGrowthInside1X128` are packed
- **Algebra**: Combined via `FeeRevenuePerLiquidityX96Lib` price-weighted merge into left; right is zero

Adapters MUST implement the three-branch tick logic (below/in/above range) internally. The caller receives the correct growthInside regardless of current tick position.

### Adapter Implementations

| Adapter | Source Data | Key Discovery |
|---------|-----------|---------------|
| **AngstromAccumulator** | `GrowthOutsideUpdater` storage (slot 7, verified by Exercise B) | `fee=0` in V4 events. MUST read from hook storage, not V4 PoolManager fee accumulators. Bundle rewards are separate. |
| **UniswapV3Accumulator** | `feeGrowthInside0LastX128` / `feeGrowthInside1LastX128` | Standard V3 fee growth. Reuse Panoptic's `FeesCalc.sol` pattern. |
| **UniswapV4Accumulator** | `StateLibrary.getFeeGrowthInside()` | V4 native fee growth. Reuse existing `NativeUniswapV4Facet.sol` read pattern. |
| **AlgebraAccumulator** | Algebra timepoint accumulator via `TimePointExtLib.sol` | `src/AlgebraIntegration/` has hook + global fee revenue libs, but `TimePointExtLib.sol` is a stub. Range-scoped growthInside requires new implementation. **Deferred to post-V1.** |

### Angstrom Storage Layout (from Exercise B, verified on mainnet)

```
struct_base = keccak256(abi.encode(poolId, 7))    // slot 7 = poolRewards mapping
rewardGrowthOutside[tick] = struct_base + uint24(tick)
globalGrowth = struct_base + 16777216             // 2^24 offset

// Three-branch growthInside computation (all adapters must implement):
// Case 1: current_tick < tickLower
//   growthInside = rewardGrowthOutside[lower] - rewardGrowthOutside[upper]
// Case 2: current_tick in [tickLower, tickUpper)
//   growthInside = globalGrowth - rewardGrowthOutside[lower] - rewardGrowthOutside[upper]
// Case 3: current_tick >= tickUpper
//   growthInside = rewardGrowthOutside[upper] - rewardGrowthOutside[lower]
// Reference: NativeUniswapV4Facet.poolRangeFeeGrowthInside() for the canonical 3-branch pattern
```

4 RPC reads per observation: 3 Angstrom storage slots + 1 V4 PoolManager slot0 (current tick).

---

## 6. Collateral Model

### Panoptic CollateralTracker Pattern

Both sides of the note deposit collateral:

- **Short (LP / theta seller)**: Deposits collateral to back the theta stream they're selling. If realized theta exceeds what they can pay, they get liquidated.
- **Long (hedger / theta buyer)**: Deposits collateral (streaming premium). Pays for the right to receive smoothed theta income.

### Collateral Requirements

```
requiredCollateral_short = f(range_width, volatility, liquidity_units)
requiredCollateral_long  = premium_owed + maintenance_margin
```

The collateral ratio and liquidation threshold are governance-settable parameters, following Panoptic's `RiskParameters` pattern.

### Liquidation

When `collateral_ratio < liquidation_threshold`:
- Force-exercise mechanism (Panoptic's `forceExercise` pattern)
- Collateral covers outstanding claims
- Position is closed, remaining collateral returned

---

## 7. Reusable Code Map

### From Panoptic (`~/apps/liq-soldk-dev/lib/2025-12-panoptic/`)

| File | Reuse |
|------|-------|
| `tokens/ERC1155Minimal.sol` | Base token standard for the note |
| `SemiFungiblePositionManager.sol` | Premium accumulator pipeline (`s_accountPremiumOwed`, `s_accountPremiumGross`) |
| `CollateralTracker.sol` | Two-sided collateral management pattern |
| `types/LeftRight.sol` | Two-token (token0/token1) accounting in single uint256 |
| `types/LiquidityChunk.sol` | Pack (tickLower, tickUpper, liquidity) for tokenId |
| `libraries/FeesCalc.sol` | V3/V4 fee growth reading logic |
| `libraries/Math.sol` | Fixed-point math utilities |

### From Angstrom (`~/apps/liq-soldk-dev/lib/angstrom/`)

| File | Reuse |
|------|-------|
| `modules/GrowthOutsideUpdater.sol` | Reference implementation for accumulator math |
| `modules/PoolUpdates.sol` | Reward-preserving liquidity adjustment formula |

### From ThetaSwap (this repo)

| File | Reuse |
|------|-------|
| `src/fee-concentration-index-v2/types/EpochSnapshot.sol` | Epoch snapshot infrastructure |
| `src/protocol-adapter/` | Base protocol adapter pattern |
| `src/AlgebraIntegration/` | Algebra accumulator reading |
| `src/fci-token-vault/modules/CollateralCustodianMod.sol` | Diamond storage slot convention reference only (existing module is simple paired LONG/SHORT mint-burn; CollateralManager requires new implementation with asymmetric collateral, per-tokenId tracking, and liquidation) |
| `src/fci-token-vault/tokens/ERC20WrapperFacade.sol` | Token wrapping pattern for composability |

---

## 8. Differential Testing / Modeling Environment

### Purpose

Since Exercise B data extraction is blocked on API credits, the on-chain contracts serve as a simulation testbed. The paper equations become differential tests — the contract's behavior is compared against theoretical predictions.

### Fork Test Framework

```
Setup:  Fork mainnet at specific block
Read:   Angstrom GrowthOutsideUpdater state (4 RPC reads)
Compute: RAN accumulator delta (Solidity)

FFI call to Python (research/scripts/ran_oracle.py):
  Bichuch-Feinstein: implied_fee_rate = LVR / L
  Panoptic convergence: fee_rate ≈ σ²S²L / (2·width)
  Pap RAN pricing: V_RAN = Σ digital_option_prices
  Capponi: E[τ] = expected_first_passage_time

Assert: |contract_value - paper_value| < epsilon
```

Extends existing pattern: `test/**/FeeConcentrationIndex.fork.t.sol` + `research/scripts/hhi_oracle.py`.

### What This Tests Without Real Data

| Model | What the Fork Test Validates |
|-------|----------------------------|
| Panoptic convergence | Does `growthInside_delta / epochs` converge to `σ²S²L / (2·width)` over enough blocks? |
| Bichuch-Feinstein | Does the implied fee rate from the accumulator match LVR computed from price changes? |
| Capponi first-passage | Does the note's accrual pattern match expected behavior given range width and realized vol? |
| FLAIR concentration | Does the FCI measured across note holders reflect the expected HHI from the accumulator distribution? |

### Connection to Exercise B

When the Exercise B data pipeline is eventually unblocked:
- `WTP(gamma)` schedule calibrates the VEGOID_equivalent spread parameter
- `beta_1` (bid elasticity) and `beta_2` (vol elasticity) determine if spread should be adaptive
- Exclusion restriction test validates that the RAN cleanly captures theta (not delta contamination)

Exercise B artifacts already built and reusable:
- GrowthOutsideUpdater storage layout (verified on mainnet)
- Dune queries (Q1-Q5, cached ~90 days)
- `extract_angstrom_growth.py` script (ready to run with dRPC key)
- Three regime periods identified (only Period 3 = mature regime is policy-relevant)

---

## 9. Success Criteria and Failure Modes

### Success Criteria

| Criterion | Measurement | Threshold |
|-----------|-------------|-----------|
| Minimum in-range liquidity per note | `growthInside_delta / epochs > dust_threshold` | TBD from Exercise B variance estimate |
| Both sides of market exist | `count(short_positions) > 0` per tokenId | At least 1 active short |
| Collateral solvency | `total_collateral >= total_premium_owed` | Invariant (kontrol-verified) |
| Accumulator liveness | `last_update < max_staleness` | Must update within 2 epochs |
| Spread convergence | `CV(spread) < threshold` over rolling window | CV < 0.3 after 100 epochs |
| Differential test accuracy | `|contract - paper| < epsilon` for all model equations | epsilon per-model (calibrated from fork tests) |

### Failure Modes

| Failure | Detection | Recovery |
|---------|-----------|----------|
| Price permanently exits range | `accruedTheta == 0` for >N epochs | Note still redeemable for whatever accrued. First-passage risk priced into spread. |
| Underlying LP withdraws | Accumulator returns same value for consecutive epochs | Liquidation — collateral covers outstanding claims |
| Accumulator divergence from theory | Fork test differential > epsilon | Flag for investigation — adapter bug or regime change |
| Protocol storage layout change | Fork tests against latest block fail | Deploy new adapter version, migrate notes |
| Collateral shortfall (extreme vol) | `collateral_ratio < liquidation_threshold` | Force-exercise (Panoptic pattern) |
| Zero liquidity in range | `totalLiquidity(tokenId) == 0` | No new mints allowed. Existing notes settle at accrued value. |

### Formal Invariants (kontrol verification targets)

```
// 1a. Conservation (short side): shorts receive at most what the pool accrued
∀ tokenId: total_distributed_to_shorts(tokenId) <= growthInside_delta(tokenId) * totalLiquidity(tokenId)

// 1b. Conservation (long side): longs pay at least what shorts receive (spread is non-negative)
∀ tokenId: total_paid_by_longs(tokenId) >= total_distributed_to_shorts(tokenId)

// 1c. Spread capture: difference is protocol revenue
∀ tokenId: total_paid_by_longs(tokenId) - total_distributed_to_shorts(tokenId) == protocol_revenue(tokenId)

// 2. Solvency: collateral covers all outstanding claims
∀ t: Σ collateral(t) >= Σ premiumOwed(t)

// 3. Monotonicity: accumulated theta never decreases
∀ tokenId, t1 < t2: accruedTheta(tokenId, t2) >= accruedTheta(tokenId, t1)

// 4. Epoch isolation: claims from different epochs don't cross-contaminate
∀ e1 ≠ e2: claim(tokenId_e1) does not affect accruedTheta(tokenId_e2)

// 5. Transfer neutrality: transfer doesn't change total accrued value
∀ transfer(from, to, id, amt):
  premiumOwed(from) + premiumOwed(to) == premiumOwed_before(from) + premiumOwed_before(to)

// 6. ERC-1155 supply conservation
∀ tokenId: totalSupply(tokenId) == Σ balanceOf(holder, tokenId) for all holders
```

---

## 10. EVM TDD Integration

### Tool Availability

```
foundry  ✓    bulloak  ✗ (manual tree writing)
kontrol  ✓    gambit   ✗    hevm  ✗
```

### Phase Mapping

| Contract | Phase 1 (SPECIFY) | Phase 2 (IMPLEMENT) | Phase 3 (VERIFY) |
|----------|-------------------|---------------------|------------------|
| `IAccumulatorSource` | BTT tree per adapter function | Adapter implementations | Formal proof: slot computation matches verified layout |
| `RangeAccrualNote` | BTT tree per lifecycle function (mint/claim/transfer) | ERC-1155 + premium tracking | Formal proof: conservation, solvency, monotonicity |
| `CollateralManager` | BTT tree per collateral operation | Panoptic CT pattern adaptation | Formal proof: solvency invariant holds under all paths |
| Differential tests | N/A (fork tests) | Fork test + FFI to Python models | N/A |

### Key Algebraic Properties (from EVM TDD skill `evm-tdd:references:algebraic-primitives`)

- **Conservation**: `growthInside + growthOutside = globalGrowth` always
- **Monotonicity**: `growthInside` non-decreasing while tick in range
- **Idempotency**: `claim(); claim()` = `claim()` (double-claim returns zero on second)
- **Commutativity**: Reading order of outsideBelow/outsideAbove doesn't matter

---

## 11. Scope and Non-Goals

### In Scope — V1a (Core Primitive)

- `IAccumulatorSource` interface
- `AngstromAccumulator` adapter (primary — uses Angstrom's native `GrowthOutsideUpdater` accumulation as-is)
- `RangeAccrualNote` ERC-1155 token with epoch-batched fungibility
- Basic `claim()` without premium spread (direct accumulator delta payout)
- Fork tests against mainnet Angstrom data
- Differential tests against paper equations (Panoptic convergence, Bichuch-Feinstein)

### In Scope — V1b (Counterparty Risk Layer)

- Premium tracking via SFPM accumulator pattern (adds VEGOID spread)
- CollateralManager with Panoptic CT pattern (new implementation, not adaptation)
- `UniswapV3Accumulator` adapter
- Liquidation / force-exercise
- VEGOID_equivalent as governance-settable constant

### Out of Scope (Future Extensions)

- `AlgebraAccumulator` adapter (stub state — requires new range-scoped implementation)
- `UniswapV4Accumulator` adapter (straightforward but deferred to reduce V1 scope)
- Vault wrapping (Approach B from brainstorming)
- Derivative overlay / theta swap engine (Approach C)
- Adaptive VEGOID based on Exercise B regression results
- ACCRUAL_DECRUAL, TARN, BARRIERS, CALLABLE, BASKET, FLOATING_COUPON extension flags
- Cross-chain deployment
- Exercise B econometric estimation (blocked on API credits)

### Accumulation Standard

The `AngstromAccumulator` uses Angstrom's native `GrowthOutsideUpdater` accumulation directly — it does not reimplement or modify the accumulation logic. The adapter is a **read-only view** over Angstrom's existing storage. Whatever Angstrom accumulates (auction bid surplus distributed pro-rata to in-range LPs), that is what the RAN tokenizes. This ensures:
- No divergence between Angstrom's reward distribution and the RAN's value
- No maintenance burden from tracking Angstrom protocol upgrades in custom accumulation code
- The RAN's value is exactly verifiable against Angstrom's on-chain state

---

## 12. References

### Academic

- Pap, K. (2022). "Pricing Range Accrual Products." MSc Thesis, Corvinus University of Budapest.
- Kristensen, J. (2024). "Perpetual Options with Uniswap V3." Panoptic.
- Bichuch, M. & Feinstein, Z. (2025). "The Price of Liquidity: Implied Volatility of AMM Fees." arXiv:2509.23222.
- Capponi, A. & Zhu, B. (2024). "Optimal Exiting for Liquidity Provision in CFMMs."
- Milionis, J. et al. (2022). "Automated Market Making and Loss-Versus-Rebalancing." arXiv:2208.06046.
- Milionis, J., Wan, C., & Adams, A. (2023). "FLAIR: A Metric for LP Competitiveness in AMMs." arXiv:2306.09421.
- Ma, C. & Crapis, D. (2024). "On the Cost of Permissionless Liquidity Provision in AMMs."
- Singh, F. et al. (2025). "Modeling LVR via Continuous-Installment Options." arXiv:2508.02971.
- Risk, T., Tung, W., & Wang, H. (2026). "Pricing and hedging for liquidity provision in CFMM." arXiv:2603.01344.

### Code References

- Angstrom `GrowthOutsideUpdater.sol`: `~/apps/liq-soldk-dev/lib/angstrom/contracts/src/modules/`
- Panoptic SFPM: `~/apps/liq-soldk-dev/lib/2025-12-panoptic/contracts/SemiFungiblePositionManager.sol`
- Panoptic CollateralTracker: `~/apps/liq-soldk-dev/lib/2025-12-panoptic/contracts/CollateralTracker.sol`
- ThetaSwap FCI V2: `src/fee-concentration-index-v2/`
- Exercise B Session Summary: `research/notes/EXERCISE_B_SESSION_SUMMARY.md`
- Angstrom Research: `research/notes/ANGSTROM_RESEARCH.md`
- Range Accrual Demand Brief: `research/notes/RANGE_ACCRUAL_DEMAND_BRIEF.md`
