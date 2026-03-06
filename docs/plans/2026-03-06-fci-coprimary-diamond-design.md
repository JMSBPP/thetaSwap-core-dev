# FCI Upgrade: Co-Primary State + Diamond Pattern

**Date**: 2026-03-06 | **Branch**: new branch off `001-fee-concentration-index`

## Problem

The current FeeConcentrationIndex implementation has two gaps relative to `specs/model/main.tex`:

1. **Missing co-primary state**: The spec defines three co-primary variables (A_T, Theta, N) needed to compute Delta+ = max(0, A_T - A_T^{1/N}) where A_T^{1/N} = sqrt(Theta/N^2). The current code only tracks AccumulatedHHI (which gives A_T). Neither thetaSum (Theta) nor posCount (N) are stored.

2. **BaseHook inheritance**: `FeeConcentrationIndex is BaseHook` prevents diamond pattern compatibility. The MasterHook diamond dispatches via `delegatecall` to facets — facets cannot inherit from BaseHook (which stores `poolManager` as a constructor-set immutable tied to a specific deployment address).

## Approach: Type-First Bottom-Up (TDD)

Phase 1: Define the co-primary state type with invariants and tests.
Phase 2: Remove BaseHook and wire the new type into the hook contract.

## Design

### 1. Type: FeeConcentrationStateMod.sol

Replace `AccumulatedHHIMod.sol` (bare `type AccumulatedHHI is uint256`) with a struct bundling all three co-primary state variables:

```solidity
struct FeeConcentrationState {
    uint256 accumulatedSum;  // Sigma(theta_k * x_k^2) in Q128 (cumulative over removals)
    uint256 thetaSum;        // Sigma(1/ell_k) in Q128 (cumulative over removals)
    uint256 posCount;        // N = active position count (increments on add, decrements on remove)
}
```

Free functions on the struct:

| Function | Returns | Description |
|----------|---------|-------------|
| `addTerm(self, blockLifetime, xSquaredQ128)` | `FeeConcentrationState` | sum += theta*x^2, thetaSum += theta |
| `incrementPos(self)` | `FeeConcentrationState` | posCount += 1 (called at afterAddLiquidity) |
| `decrementPos(self)` | `FeeConcentrationState` | posCount -= 1 (called at afterRemoveLiquidity) |
| `toIndexA(self)` | `uint128` | A_T = sqrt(accumulatedSum) in Q128, capped at 1.0 |
| `atNull(self)` | `uint256` | A_T^{1/N} = sqrt(thetaSum / posCount^2) in Q128 |
| `deltaPlus(self)` | `uint256` | max(0, toIndexA - atNull) in Q128 |
| `toDeltaPlusPrice(self)` | `uint256` | p = deltaPlus / (Q128 - deltaPlus) in Q128 |

The `AccumulatedHHI` UDVT is removed. `toIndexB()` is removed (B_T is no longer primary per spec).

**Invariants** (from spec FCI-01 through FCI-11):
- FCI-01: 0 <= A_T <= 1
- FCI-02: thetaSum >= 0
- FCI-03: posCount >= 0
- FCI-04: A_T >= atNull when posCount > 0
- FCI-05: deltaPlus >= 0
- FCI-06: deltaPlus < 1
- FCI-07: atNull and deltaPlus are deterministic functions of (accumulatedSum, thetaSum, posCount)

### 2. Hook Contract: Remove BaseHook

- Remove `is BaseHook` and `constructor(poolManager)`
- `poolManager` becomes an `immutable` set in the facet's own constructor (immutables live in bytecode, survive `delegatecall`)
- Remove `override` keywords on all hook functions
- Rename `_afterAddLiquidity` -> `afterAddLiquidity` (public/external, called via delegatecall from MasterHook)
- Same for `_beforeSwap`, `_afterSwap`, `_beforeRemoveLiquidity`, `_afterRemoveLiquidity`
- `getHookPermissions()` removed — this is the MasterHook's concern, not the facet's
- Return types match raw IHooks signatures

### 3. Storage Update

```
FeeConcentrationIndexStorage {
    mapping(PoolId => FeeConcentrationState) fciState;  // was: accumulatedHHI
    mapping(PoolId => TickRangeRegistry) registries;     // unchanged
    mapping(PoolId => mapping(bytes32 => uint256)) feeGrowthBaseline0;  // unchanged
}
```

Hook wiring:
- `afterAddLiquidity`: after `register()`, call `fciState[poolId].incrementPos()`
- `afterRemoveLiquidity`: after `addTerm()`, call `fciState[poolId].decrementPos()`

### 4. Interface Update

```solidity
interface IFeeConcentrationIndex {
    function getIndex(PoolKey calldata key)
        external view returns (uint128 indexA, uint256 thetaSum, uint256 posCount);
}
```

Callers compute Delta+ and p on the fly (spec: "Delta+ is not stored"):
```
atNull = sqrt(thetaSum / posCount^2)
deltaPlus = max(0, indexA - atNull)
p = deltaPlus / (1 - deltaPlus)
```

## Files Changed

| File | Action | Phase |
|------|--------|-------|
| `src/fee-concentration-index/types/FeeConcentrationStateMod.sol` | Create (replaces AccumulatedHHIMod.sol) | 1 |
| `src/fee-concentration-index/types/AccumulatedHHIMod.sol` | Delete | 1 |
| `test/fee-concentration-index/unit/FeeConcentrationState.t.sol` | Create | 1 |
| `test/fee-concentration-index/kontrol/FeeConcentrationState.k.sol` | Create | 1 |
| `test/fee-concentration-index/kontrol/AccumulatedHHI.k.sol` | Delete | 1 |
| `src/fee-concentration-index/FeeConcentrationIndex.sol` | Rewrite (remove BaseHook, wire new type) | 2 |
| `src/fee-concentration-index/interfaces/IFeeConcentrationIndex.sol` | Update return type | 2 |
| `src/fee-concentration-index/modules/FeeConcentrationIndexStorageMod.sol` | Update mapping type | 2 |
| `test/fee-concentration-index/unit/*.t.sol` | Update for new signatures | 2 |
| `test/fee-concentration-index/harness/*.sol` | Update (remove BaseHook adapter) | 2 |

## Verification

1. `forge test --out out2` — all unit and fuzz tests pass
2. Invariants FCI-01 through FCI-11 covered by fuzz tests
3. Kontrol proofs for type round-trips
4. `getIndex()` returns correct (A_T, Theta, N) triple
5. Delta+ computed from triple matches expected values from backtest data
