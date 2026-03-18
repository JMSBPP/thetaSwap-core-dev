# Dead/Orphaned Test File Analysis

**Date**: 2026-03-17
**Branch**: `008-uniswap-v3-reactive-integration`
**Analyst**: Papa Bear

---

## Executive Summary

Of 46 Solidity test/helper files under `test/`, **18 are DEAD** (testing superseded V1 FCI or old reactive-integration contracts), **24 are ALIVE** (testing current V2 FCI, vault, or simulation code), and **4 are UNCERTAIN** (shared infrastructure used by both live and dead tests, or bridge code with mixed dependencies).

The entire `test/fee-concentration-index/` directory (10 files) and most of `test/reactive-integration/` (6 of 8 files) are dead. The `test/fci-token-vault/`, `test/fee-concentration-index-v2/`, and `test/simulation/` directories are alive.

---

## Classification Criteria

| Status | Meaning |
|--------|---------|
| ALIVE | Tests V2 contracts (`src/fee-concentration-index-v2/`) or vault (`src/fci-token-vault/`). Active value. |
| DEAD | Tests only V1 FCI (`src/fee-concentration-index/`) or old reactive-integration (`src/reactive-integration/`). No current value. |
| UNCERTAIN | Mixed imports (V1+V2), or shared infrastructure consumed by both live and dead tests. Needs case-by-case decision. |

**Key remapping context** (from `foundry.toml`):
- `@fee-concentration-index/` = `src/fee-concentration-index/` (V1 -- superseded)
- `@fee-concentration-index-v2/` = `src/fee-concentration-index-v2/` (V2 -- current)
- `@reactive-integration/` = `src/reactive-integration/` (old -- superseded)
- `@protocol-adapter/` = `src/reactive-integration/template/` (old source, but still used by V2 and vault as shared dependency)
- `@fci-token-vault/` = `src/fci-token-vault/` (current)

---

## File-by-File Classification

### test/fee-concentration-index/ -- 10 files, ALL DEAD

These test the V1 `FeeConcentrationIndex` contract. V2 (`FeeConcentrationIndexV2`) has superseded it.

| # | File | Status | Rationale |
|---|------|--------|-----------|
| 1 | `unit/AfterAddLiquidity.t.sol` | DEAD | Imports `FeeConcentrationIndexHarness` which wraps V1 `@fee-concentration-index/FeeConcentrationIndex.sol` |
| 2 | `unit/AfterRemoveLiquidity.t.sol` | DEAD | Same V1 harness |
| 3 | `unit/AfterSwap.t.sol` | DEAD | Same V1 harness + `MockPositionManager` |
| 4 | `unit/EpochMetric.t.sol` | DEAD | Imports `@fee-concentration-index/modules/FeeConcentrationEpochStorageMod.sol` (V1) |
| 5 | `unit/FeeConcentrationIndexFull.unit.t.sol` | DEAD | Full V1 lifecycle test via harness |
| 6 | `unit/HookDataFlags.unit.t.sol` | DEAD | Imports from `src/reactive-integration/uniswapV3/types/HookDataFlagsMod.sol` (old) |
| 7 | `fuzz/EpochMetric.fuzz.t.sol` | DEAD | V1 epoch storage module |
| 8 | `fuzz/FeeConcentrationIndexFull.fuzz.t.sol` | DEAD | V1 harness fuzz |
| 9 | `differential/FeeConcentrationIndexForkHarness.sol` | DEAD | Wraps V1 `FeeConcentrationIndex` + `@protocol-adapter` |
| 10 | `differential/FeeConcentrationIndexPythonFFI.diff.fork.t.sol` | DEAD | Fork diff test for V1 using the harness above |

**Shared helpers also dead:**
| # | File | Status | Rationale |
|---|------|--------|-----------|
| 11 | `harness/FeeConcentrationIndexHarness.sol` | DEAD | Wraps V1 `FeeConcentrationIndex`. However, note this is imported by vault integration tests (see UNCERTAIN section). |
| 12 | `harness/MockPositionManager.sol` | DEAD | Minimal mock, only used by V1 unit tests |
| 13 | `helpers/FCITestHelper.sol` | DEAD* | Abstract helper for V4 PositionManager operations. *Imported by vault integration tests and simulation tests. See implications below. |
| 14 | `kontrol/FeeShareRatio.k.sol` | DEAD | Kontrol proof for V1 |
| 15 | `kontrol/SwapCount.k.sol` | DEAD | Kontrol proof for V1 |

**Important implication**: `FCITestHelper.sol` and `FeeConcentrationIndexHarness.sol` are dead V1 test infrastructure, but they are consumed by ALIVE vault integration tests (`HedgedVsUnhedged`, `JitGameWelfareComparison`) and simulation tests (`CapponiJITSequentialGame`). Deleting them requires migrating those consumers first.

---

### test/reactive-integration/ -- 8 files, 6 DEAD + 2 UNCERTAIN

These test the old `src/reactive-integration/` contracts (ReactiveHookAdapter, ThetaSwapReactive, V3CallbackRouter, etc.), now superseded by `src/fee-concentration-index-v2/protocols/uniswap-v3/`.

| # | File | Status | Rationale |
|---|------|--------|-----------|
| 1 | `fork/DifferentialFCI.fork.t.sol` | DEAD | Imports V1 `FeeConcentrationIndex` + old `ReactiveHookAdapter` from `@reactive-integration/` |
| 2 | `fork/FeeConcentrationIndexFull.fork.t.sol` | DEAD | Uses `@foundry-script/reactive-integration/FeeConcentrationIndexBuilder.s.sol` (old builder) |
| 3 | `fork/V3FeeGrowthReader.fork.t.sol` | DEAD | Tests `reactive-hooks` library `V3FeeGrowthReaderMod` directly, not project code. Low value. |
| 4 | `kontrol/PoolKeyExt.k.sol` | DEAD | Tests `reactive-hooks` library `PoolKeyExtMod`. Kontrol proof for external lib. |
| 5 | `uniswapV3/differential/FeeConcentrationIndexV4ReactiveV3.diff.t.sol` | DEAD | Imports both V1 FCI and old `ReactiveHookAdapter`. Three-phase diff test for the old architecture. |
| 6 | `template/ProtocolAdapterStorage.t.sol` | UNCERTAIN | Tests `@protocol-adapter/storage/ProtocolAdapterStorage.sol` which maps to `src/reactive-integration/template/`. This storage module is still imported by V2 and vault code via `@protocol-adapter`. If that dependency persists, this test has value. |
| 7 | `template/ProtocolAdapterMod.t.sol` | UNCERTAIN | Tests `@protocol-adapter/modules/ProtocolAdapterMod.sol`. Same reasoning as above -- still used by vault harnesses and V2 differential base. |
| 8 | `template/FCIProtocolFacetStorageMod.t.sol` | UNCERTAIN | Tests `@fee-concentration-index-v2/modules/FCIProtocolFacetStorageMod.sol` (V2!) but also imports V1 `FCI_STORAGE_SLOT` for disjointness assertion. Primarily a V2 test. |

---

### test/fee-concentration-index-v2/ -- 9 files, ALL ALIVE

These test the current V2 FCI contracts.

| # | File | Status | Rationale |
|---|------|--------|-----------|
| 1 | `FeeConcentrationIndexRegistryStorage.t.sol` | ALIVE | Tests `@fee-concentration-index-v2/modules/FeeConcentrationIndexRegistryStorageMod.sol` |
| 2 | `differential/FCIDifferentialBase.sol` | ALIVE | V1-vs-V2 diff test base. Imports both V1 and V2 intentionally to prove equivalence. |
| 3 | `differential/FCIV1DiffFCIV2.diff.t.sol` | ALIVE | Runs V1 vs V2 differential scenarios. Deliberately uses V1 as reference. |
| 4 | `protocols/uniswap-v3/Flow3_1_ListenDispatch.t.sol` | ALIVE | Tests V2 reactive dispatch module |
| 5 | `protocols/uniswap-v3/UniswapV3Callback.admin.t.sol` | ALIVE | Tests V2 `UniswapV3Callback` admin functions |
| 6 | `protocols/uniswap-v3/UniswapV3Reactive.admin.t.sol` | ALIVE | Tests V2 `UniswapV3Reactive` admin functions |
| 7 | `protocols/uniswap-v3/UniswapV3ReactiveDebug.t.sol` | ALIVE | Tests V2 `UniswapV3Reactive` debug/deployment |
| 8 | `protocols/uniswap-v3/integration/FeeConcentrationIndexV2Full.integration.t.sol` | ALIVE | Full V2 integration test |
| 9 | `protocols/uniswap-v3/mocks/MockCallbackReceiver.sol` | ALIVE | Mock for V2 callback tests |

---

### test/fci-token-vault/ -- 14 files, ALL ALIVE

The vault is still a valid, active component.

| # | File | Status | Rationale |
|---|------|--------|-----------|
| 1 | `FciTokenVaultMod.t.sol` | ALIVE | Tests vault module |
| 2 | `SqrtPriceLookbackPayoffX96.t.sol` | ALIVE | Tests payoff library |
| 3 | `SqrtPriceLookbackPayoffX96.fuzz.t.sol` | ALIVE | Fuzz for payoff library |
| 4 | `unit/CollateralCustodianMod.t.sol` | ALIVE | Tests custodian module |
| 5 | `unit/ERC20WrapperFacade.t.sol` | ALIVE | Tests ERC20 wrapper |
| 6 | `unit/OraclePayoffMod.t.sol` | ALIVE | Tests oracle payoff |
| 7 | `unit/ReentrancyLib.t.sol` | ALIVE | Tests reentrancy guard |
| 8 | `fuzz/CustodianHandler.sol` | ALIVE | Invariant test handler |
| 9 | `fuzz/CustodianInvariant.fuzz.t.sol` | ALIVE | Invariant fuzz test |
| 10 | `helpers/CustodianHarness.sol` | ALIVE | Test harness (uses `@protocol-adapter` but for vault setup) |
| 11 | `helpers/FciTokenVaultHarness.sol` | ALIVE | Test harness |
| 12 | `integration/HedgedVsUnhedged.integration.t.sol` | ALIVE | Integration (imports V1 harness as dependency -- see implications) |
| 13 | `integration/JitGameWelfareComparison.integration.t.sol` | ALIVE | Integration (same V1 harness dependency) |
| 14 | `integration/PayoffPipeline.integration.t.sol` | ALIVE | Integration test |
| 15 | `kontrol/SqrtPriceLookbackPayoffX96.k.sol` | ALIVE | Kontrol proof for payoff |

---

### test/simulation/ -- 2 files, ALL ALIVE

| # | File | Status | Rationale |
|---|------|--------|-----------|
| 1 | `JitGame.t.sol` | ALIVE | Tests JIT game primitives via `@foundry-script` |
| 2 | `CapponiJITSequentialGame.fork.t.sol` | ALIVE | Fork simulation (imports V1 harness as dependency) |

---

## Summary Table

| Directory | Total Files | ALIVE | DEAD | UNCERTAIN |
|-----------|------------|-------|------|-----------|
| `test/fee-concentration-index/` | 15 | 0 | 15 | 0 |
| `test/reactive-integration/` | 8 | 0 | 5 | 3 |
| `test/fee-concentration-index-v2/` | 9 | 9 | 0 | 0 |
| `test/fci-token-vault/` | 15 | 15 | 0 | 0 |
| `test/simulation/` | 2 | 2 | 0 | 0 |
| **TOTAL** | **49** | **26** | **20** | **3** |

---

## Dependency Graph: Dead Code with Live Consumers

The following dead files are imported by ALIVE tests. They cannot be deleted without migration:

```
DEAD: test/fee-concentration-index/helpers/FCITestHelper.sol
  <- ALIVE: test/fci-token-vault/integration/HedgedVsUnhedged.integration.t.sol
  <- ALIVE: test/fci-token-vault/integration/JitGameWelfareComparison.integration.t.sol
  <- ALIVE: test/simulation/CapponiJITSequentialGame.fork.t.sol
  <- ALIVE: test/fee-concentration-index-v2/differential/FCIDifferentialBase.sol

DEAD: test/fee-concentration-index/harness/FeeConcentrationIndexHarness.sol
  <- ALIVE: test/fci-token-vault/integration/HedgedVsUnhedged.integration.t.sol
  <- ALIVE: test/fci-token-vault/integration/JitGameWelfareComparison.integration.t.sol
  <- ALIVE: test/simulation/CapponiJITSequentialGame.fork.t.sol
```

---

## Recommendations

### Phase 1: Safe Deletions (no downstream impact)

Delete these 13 files immediately -- nothing alive depends on them:

1. `test/fee-concentration-index/unit/AfterAddLiquidity.t.sol`
2. `test/fee-concentration-index/unit/AfterRemoveLiquidity.t.sol`
3. `test/fee-concentration-index/unit/AfterSwap.t.sol`
4. `test/fee-concentration-index/unit/EpochMetric.t.sol`
5. `test/fee-concentration-index/unit/FeeConcentrationIndexFull.unit.t.sol`
6. `test/fee-concentration-index/unit/HookDataFlags.unit.t.sol`
7. `test/fee-concentration-index/fuzz/EpochMetric.fuzz.t.sol`
8. `test/fee-concentration-index/fuzz/FeeConcentrationIndexFull.fuzz.t.sol`
9. `test/fee-concentration-index/differential/FeeConcentrationIndexForkHarness.sol`
10. `test/fee-concentration-index/differential/FeeConcentrationIndexPythonFFI.diff.fork.t.sol`
11. `test/fee-concentration-index/kontrol/FeeShareRatio.k.sol`
12. `test/fee-concentration-index/kontrol/SwapCount.k.sol`
13. `test/fee-concentration-index/harness/MockPositionManager.sol`

### Phase 2: Safe Deletions from reactive-integration

Delete these 5 files -- old architecture tests with no alive consumers:

14. `test/reactive-integration/fork/DifferentialFCI.fork.t.sol`
15. `test/reactive-integration/fork/FeeConcentrationIndexFull.fork.t.sol`
16. `test/reactive-integration/fork/V3FeeGrowthReader.fork.t.sol`
17. `test/reactive-integration/kontrol/PoolKeyExt.k.sol`
18. `test/reactive-integration/uniswapV3/differential/FeeConcentrationIndexV4ReactiveV3.diff.t.sol`

### Phase 3: Migrate then Delete

Before deleting these, migrate their live consumers:

19. `test/fee-concentration-index/helpers/FCITestHelper.sol` -- Move to `test/shared/` or `test/helpers/`. It provides generic V4 PositionManager wrappers, not V1-specific logic.
20. `test/fee-concentration-index/harness/FeeConcentrationIndexHarness.sol` -- Still needed by V2 differential tests and vault integration. Either keep in place or move to `test/shared/`.

### Phase 4: Resolve UNCERTAIN files

21. `test/reactive-integration/template/ProtocolAdapterStorage.t.sol` -- Keep if `@protocol-adapter` remapping persists. Delete if protocol adapter moves into V2.
22. `test/reactive-integration/template/ProtocolAdapterMod.t.sol` -- Same.
23. `test/reactive-integration/template/FCIProtocolFacetStorageMod.t.sol` -- Primarily V2. Move to `test/fee-concentration-index-v2/` for clarity.

### Longer-term: Source code cleanup

The `@protocol-adapter` remapping still points to `src/reactive-integration/template/`, meaning that old source directory cannot be fully deleted until the protocol adapter pattern is either:
- Absorbed into `src/fee-concentration-index-v2/`, or
- Extracted to its own top-level `src/protocol-adapter/` directory
