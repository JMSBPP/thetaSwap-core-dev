# Dead/Orphaned Code Analysis: `src/` Directory

**Date**: 2026-03-17
**Branch**: `008-uniswap-v3-reactive-integration`
**Analyst**: Papa Bear

---

## Executive Summary

The `src/` directory contains 6 top-level entries. Of these, **FCI V2** and the **vault** are the active system. However, both depend on shared types from V1 and the old reactive-integration template -- meaning those directories cannot be deleted wholesale. The analysis reveals:

- **19 files** are ALIVE (actively imported by FCI V2, vault, or transitively required)
- **21 files** are DEAD (legacy V1 implementation, old reactive adapters, build artifacts)
- **3 files** are UNCERTAIN (only used by V1's FeeConcentrationIndex.sol which itself is a borderline dependency)
- **1 directory** (`thetaswap_simulation.egg-info/`) is a Python build artifact that should not be in `src/`

---

## Import Dependency Graph (What V2 + Vault Actually Need)

### From `@fee-concentration-index/` (remapped to `src/fee-concentration-index/`)

FCI V2 production code imports exactly 2 files from V1:

| V1 File | Imported By (V2) | What Is Used |
|---------|-------------------|--------------|
| `interfaces/IFeeConcentrationIndex.sol` | `FeeConcentrationIndexV2.sol`, `FCIFacetAdminStorageMod.sol`, `UniswapV3Facet.sol`, `NativeUniswapV4Facet.sol` | Interface type for `IFeeConcentrationIndex` |
| `modules/FeeConcentrationEpochStorageMod.sol` | `FeeConcentrationIndexV2.sol`, `FCIProtocolFacetStorageMod.sol`, `UniswapV3Facet.sol`, `NativeUniswapV4Facet.sol` | `FeeConcentrationEpochStorage` struct + free functions |

### From `@protocol-adapter/` (remapped to `src/reactive-integration/template/`)

FCI V2 production code imports 1 file; vault imports 2 files:

| Template File | Imported By | What Is Used |
|---------------|-------------|--------------|
| `interfaces/IProtocolStateView.sol` | V2: `FeeConcentrationIndexV2.sol`, `FCIFacetAdminStorageMod.sol`, `FCIProtocolLib.sol`, `UniswapV3Facet.sol`, `NativeUniswapV4Facet.sol` | Empty marker interface |
| `storage/ProtocolAdapterStorage.sol` | Vault: `OraclePayoffMod.sol` | `ProtocolAdapterStorage` struct |
| `libraries/ProtocolAdapterLib.sol` | Vault: `OraclePayoffMod.sol` | `getDeltaPlusEpoch()` function |

### From `@reactive-integration/` (remapped to `src/reactive-integration/`)

FCI V2 imports 1 file:

| File | Imported By | What Is Used |
|------|-------------|--------------|
| `template/interfaces/IUnlockCallbackReactiveExt.sol` | `ReactiveDispatchMod.sol` | `IUnlockCallbackReactiveExt` interface |

### From `@libraries/` (remapped to `src/libraries/`)

| File | Imported By | What Is Used |
|------|-------------|--------------|
| `HookUtilsMod.sol` | `FeeConcentrationIndexV2.sol` | `sortTicks()` free function |

### Transitive Dependencies

`src/libraries/HookUtilsMod.sol` imports from:
- `src/reactive-integration/libraries/PoolKeyExtMod.sol` (for `v3PositionKey`)
- `src/reactive-integration/uniswapV3/types/HookDataFlagsMod.sol` (for `isUniswapV3`, `isUniswapV4`)

`src/reactive-integration/template/libraries/ProtocolAdapterLib.sol` imports from:
- `src/fee-concentration-index/modules/FeeConcentrationIndexStorageMod.sol` (for `fciStorage`, `reactiveFciStorage`)
- `src/reactive-integration/uniswapV3/types/HookDataFlagsMod.sol` (for `isUniswapV3Reactive`)
- `src/fee-concentration-index/interfaces/IFeeConcentrationIndex.sol`

---

## File-by-File Classification

### `src/fee-concentration-index-v2/` -- ALL ALIVE

Every file in this directory is part of the active V2 system.

| File | Status |
|------|--------|
| `FeeConcentrationIndexV2.sol` | ALIVE -- core V2 contract |
| `FCIProtocolFacet.sol` | ALIVE -- protocol facet |
| `interfaces/IFCIProtocolFacet.sol` | ALIVE |
| `interfaces/IFeeConcentrationIndexV2.sol` | ALIVE |
| `libraries/FCIProtocolLib.sol` | ALIVE |
| `libraries/PoolAddedSig.sol` | ALIVE |
| `libraries/PoolKeyExtLib.sol` | ALIVE |
| `modules/dependencies/AdminLib.sol` | ALIVE |
| `modules/dependencies/LibOwner.sol` | ALIVE |
| `modules/FCIFacetAdminStorageMod.sol` | ALIVE |
| `modules/FCIProtocolFacetStorageMod.sol` | ALIVE |
| `modules/FeeConcentrationIndexRegistryStorageMod.sol` | ALIVE |
| `modules/FeeConcentrationIndexStorageV2Mod.sol` | ALIVE |
| `modules/ReactiveDispatchMod.sol` | ALIVE |
| `protocols/uniswap-v3/*` (all 13 files) | ALIVE |
| `protocols/uniswap-v4/*` (both files) | ALIVE |
| `types/FlagsRegistry.sol` | ALIVE |
| `types/LiquidityPositionSnapshot.sol` | ALIVE |

### `src/fci-token-vault/` -- ALL ALIVE

Per instructions, the vault is still valid. All files confirmed to have active imports and tests.

| File | Status |
|------|--------|
| All 13 files | ALIVE |

### `src/fee-concentration-index/` (V1) -- MIXED

| File | Status | Reason |
|------|--------|--------|
| `interfaces/IFeeConcentrationIndex.sol` | **ALIVE** | Imported by 5+ V2 production files and ProtocolAdapterLib |
| `modules/FeeConcentrationEpochStorageMod.sol` | **ALIVE** | Imported by 4 V2 production files |
| `modules/FeeConcentrationIndexStorageMod.sol` | **ALIVE** | Imported transitively by ProtocolAdapterLib (used by vault) |
| `FeeConcentrationIndex.sol` | **UNCERTAIN** | V1 implementation contract. Imported by V2 differential tests (`FCIDifferentialBase.sol`) for reference testing. Not imported by any V2 production contract. Could be moved to `test/` helpers. |

### `src/reactive-integration/` -- MOSTLY DEAD

#### Still needed by V2/vault (ALIVE via `@protocol-adapter/` remapping):

| File | Status | Reason |
|------|--------|--------|
| `template/interfaces/IProtocolStateView.sol` | **ALIVE** | Imported by 5 V2 files |
| `template/interfaces/IUnlockCallbackReactiveExt.sol` | **ALIVE** | Imported by V2's ReactiveDispatchMod.sol |
| `template/storage/ProtocolAdapterStorage.sol` | **ALIVE** | Imported by vault's OraclePayoffMod |
| `template/libraries/ProtocolAdapterLib.sol` | **ALIVE** | Imported by vault's OraclePayoffMod |

#### Still needed transitively (ALIVE via `HookUtilsMod.sol` or `ProtocolAdapterLib.sol`):

| File | Status | Reason |
|------|--------|--------|
| `libraries/PoolKeyExtMod.sol` | **ALIVE** | Imported by `src/libraries/HookUtilsMod.sol` |
| `uniswapV3/types/HookDataFlagsMod.sol` | **ALIVE** | Imported by HookUtilsMod.sol + ProtocolAdapterLib.sol + FeeConcentrationIndexStorageExt.sol + FeeGrowthReaderExt.sol |

#### Only needed by V1's FeeConcentrationIndex.sol (UNCERTAIN):

| File | Status | Reason |
|------|--------|--------|
| `libraries/FeeConcentrationIndexStorageExt.sol` | **UNCERTAIN** | Imported only by V1's `FeeConcentrationIndex.sol` |
| `libraries/FeeGrowthReaderExt.sol` | **UNCERTAIN** | Imported only by V1's `FeeConcentrationIndex.sol` |
| `template/modules/ProtocolAdapterMod.sol` | **UNCERTAIN** | Imported by V1's `FeeConcentrationIndex.sol` and by `FeeConcentrationIndexStorageMultiProtocolReactiveExtMod.sol` |

#### DEAD -- old reactive adapter / V1 infrastructure:

| File | Status | Reason |
|------|--------|--------|
| `adapters/uniswapV3/ReactiveAuthMod.sol` | **DEAD** | Old V1 adapter, superseded by V2's UniswapV3Callback.sol |
| `adapters/uniswapV3/ReactiveHookAdapter.sol` | **DEAD** | Old V1 adapter contract |
| `adapters/uniswapV3/ReactiveHookAdapterStorageMod.sol` | **DEAD** | Old V1 adapter storage |
| `adapters/uniswapV3/ReactiveHookAdapterTranslateMod.sol` | **DEAD** | Old V1 adapter translation module |
| `adapters/uniswapV3/V3CallbackRouter.sol` | **DEAD** | Old V1 callback router |
| `FeeConcentrationIndexV2.sol` | **DEAD** | Old intermediate V2 in wrong directory; superseded by `src/fee-concentration-index-v2/FeeConcentrationIndexV2.sol` |
| `ThetaSwapReactive.sol` | **DEAD** | Old V1 reactive contract; superseded by V2's UniswapV3Reactive.sol |
| `modules/FeeConcentrationIndexStorageMultiProtocolReactiveExtMod.sol` | **DEAD** | Old multi-protocol module |
| `template/interfaces/IFCIProtocolAdmin.sol` | **DEAD** | Not imported by any V2 file |
| `template/interfaces/IFCIProtocolFacet.sol` | **DEAD** | Not imported by any V2 file (V2 has its own `IFCIProtocolFacet.sol`) |
| `uniswapV3/libraries/UniswapV3UniswapV4HookLib.sol` | **DEAD** | Old V3-to-V4 hook translation |
| `uniswapV3/modules/UniswapV3ReactiveMod.sol` | **DEAD** | Old V3 reactive module |
| `uniswapV3/types/TickShadow.sol` | **DEAD** | Old tick shadow type |
| `uniswapV3/types/UniswapV3CallbackData.sol` | **DEAD** | Old callback data type |
| `uniswapV4/types/HooksCallData.sol` | **DEAD** | Old V4 hooks call data type |

### `src/libraries/` -- ALIVE

| File | Status | Reason |
|------|--------|--------|
| `HookUtilsMod.sol` | **ALIVE** | Imported by `FeeConcentrationIndexV2.sol` (for `sortTicks`) and by V1's `FeeConcentrationIndex.sol` |

### `src/thetaswap_simulation.egg-info/` -- DEAD

| Entry | Status | Reason |
|-------|--------|--------|
| Entire directory | **DEAD** | Python setuptools build artifact. Should never be in `src/`. Should be in `.gitignore`. |

---

## Summary Counts

| Classification | File Count | Directories Affected |
|---------------|------------|---------------------|
| **ALIVE** | 19 files (outside V2/vault) | V1: 3 files, reactive-integration/template: 4 files, reactive-integration transitive: 2 files, libraries: 1 file |
| **DEAD** | 21 files + 1 directory | reactive-integration: 15 files, V1 reactive FCI: 1 file, reactive adapters: 5 files, egg-info: 1 dir |
| **UNCERTAIN** | 4 files | V1 FeeConcentrationIndex.sol + 3 reactive-integration libs used only by V1 |

---

## Recommendations

### Immediate Cleanup (Safe, No Impact on V2/Vault)

1. **Delete `src/thetaswap_simulation.egg-info/`** -- Python build artifact, add to `.gitignore`

2. **Delete these dead reactive-integration files:**
   - `src/reactive-integration/adapters/` (entire directory -- 5 files)
   - `src/reactive-integration/FeeConcentrationIndexV2.sol`
   - `src/reactive-integration/ThetaSwapReactive.sol`
   - `src/reactive-integration/modules/FeeConcentrationIndexStorageMultiProtocolReactiveExtMod.sol`
   - `src/reactive-integration/template/interfaces/IFCIProtocolAdmin.sol`
   - `src/reactive-integration/template/interfaces/IFCIProtocolFacet.sol`
   - `src/reactive-integration/uniswapV3/libraries/UniswapV3UniswapV4HookLib.sol`
   - `src/reactive-integration/uniswapV3/modules/UniswapV3ReactiveMod.sol`
   - `src/reactive-integration/uniswapV3/types/TickShadow.sol`
   - `src/reactive-integration/uniswapV3/types/UniswapV3CallbackData.sol`
   - `src/reactive-integration/uniswapV4/` (entire directory)

3. **Also delete corresponding dead tests:**
   - `test/reactive-integration/` likely has tests only for the old adapter (verify first)

### Medium-Term Refactoring (Requires Code Changes)

4. **Extract shared types out of V1/reactive-integration**: The 9 ALIVE files scattered across `src/fee-concentration-index/` and `src/reactive-integration/template/` are really shared infrastructure. Consider:
   - Move `IFeeConcentrationIndex.sol` to `src/fee-concentration-index-v2/interfaces/` (it defines the interface V2 implements)
   - Move `FeeConcentrationEpochStorageMod.sol` to `src/fee-concentration-index-v2/modules/`
   - Move `FeeConcentrationIndexStorageMod.sol` to `src/fee-concentration-index-v2/modules/` (or a shared `src/storage/`)
   - Move `IProtocolStateView.sol`, `ProtocolAdapterStorage.sol`, `ProtocolAdapterLib.sol`, `IUnlockCallbackReactiveExt.sol` to a `src/shared/` or into V2's module tree
   - Move `HookDataFlagsMod.sol` and `PoolKeyExtMod.sol` to `src/libraries/`

   After this extraction, both `src/fee-concentration-index/` and `src/reactive-integration/` could be deleted entirely.

5. **Resolve V1 FeeConcentrationIndex.sol**: Used only by V2 differential tests. Move to `test/fee-concentration-index-v2/helpers/` or `test/shared/` so it is clearly a test dependency, not production code.

### Cleanup Impact on Remappings

After cleanup, these foundry.toml remappings become unnecessary:
- `@reactive-integration/` (if all needed files are relocated)
- `@fee-concentration-index/` (if shared types are moved to V2)
- `@protocol-adapter/` (if template files are moved to V2 or shared)

---

## Risk Assessment

- **Deleting DEAD files**: Zero risk to V2/vault compilation. These files have no import path from any V2 production contract.
- **Deleting UNCERTAIN files**: Would break V1's `FeeConcentrationIndex.sol`. If V1 is kept for differential testing, these must stay.
- **Moving ALIVE files**: Requires updating import paths in V2, vault, and tests. Mechanical but touches many files. Recommend doing it as a dedicated refactor branch.
