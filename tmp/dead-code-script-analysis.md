# Dead / Orphaned Script Analysis
**Branch**: `008-uniswap-v3-reactive-integration`
**Date**: 2026-03-17
**Scope**: `foundry-script/` (no `script/` directory exists in the repo)

---

## Summary

| File | Classification | Reason |
|------|---------------|--------|
| `foundry-script/deploy/DeployFci.s.sol` | ALIVE | Deploys both V1 and V2; primary deploy script for FCI V2 + NativeUniswapV4Facet |
| `foundry-script/deploy/DeployReactiveAdapterV3.s.sol` | DEAD | Deploys old `ReactiveHookAdapter` from `src/reactive-integration/`; superseded by FCI V2's `UniswapV3Facet` / `UniswapV3Reactive` |
| `foundry-script/deploy/DeployFCIHookV4.s.sol` | DEAD | Deploys FCI V1 only (`FeeConcentrationIndex`), no V2 awareness; superseded by `DeployFci.s.sol` |
| `foundry-script/deploy/CompareDeltaPlus.s.sol` | DEAD | Reads from old `ReactiveHookAdapter`; compares V4 vs V3 via old adapter architecture |
| `foundry-script/deploy/CreateFreshPools.s.sol` | UNCERTAIN | Infrastructure-level (creates V3 + V4 pools); no direct V1/V2 coupling, but was built for the old differential test flow |
| `foundry-script/deploy/CreatePoolV3.s.sol` | UNCERTAIN | Generic V3 pool creation; no FCI coupling; could serve V2 flow |
| `foundry-script/deploy/CreatePoolV4.s.sol` | UNCERTAIN | Generic V4 pool init using `ethSepoliaFCIHook()` address (V1 hook address) in Deployments; currently would point at V1 hook |
| `foundry-script/deploy/ApproveV3Router.s.sol` | DEAD | Approves tokens to old `V3CallbackRouter` deployed by old reactive-integration; no role in V2 flow |
| `foundry-script/deploy/DeploySwapRouter.s.sol` | ALIVE | Deploys `PoolSwapTest` for V4; no FCI coupling; valid infrastructure |
| `foundry-script/deploy/DeployMockTokens.s.sol` | ALIVE | Deploys mock ERC20 tokens; no FCI coupling; valid infrastructure |
| `foundry-script/deploy/FundAccounts.s.sol` | UNCERTAIN | Funds test accounts; calls `resolveV3()` which uses stale `sepoliaAdapter()` + `sepoliaFCI()` addresses |
| `foundry-script/deploy/DeployV3CallbackRouter.s.sol` | DEAD | Deploys old `V3CallbackRouter` from `src/reactive-integration/`; superseded by V2 facet architecture |
| `foundry-script/reactive-integration/FeeConcentrationIndexBuilder.s.sol` | DEAD | Entire script built around `ReactiveHookAdapter` (old `src/reactive-integration/`); hardwires `sepoliaReactiveAdapter()` = `0xC1ED47...` (the old V3 adapter, not the V2 system) |
| `foundry-script/reactive-integration/run-differential.sh` | DEAD | Orchestrates the old differential test flow: deploys `ReactiveHookAdapter` + `ThetaSwapReactive` from `src/reactive-integration/`; the referenced test file `FeeConcentrationIndexV4ReactiveV3.diff.t.sol` likely no longer compiles against V2 contracts |
| `foundry-script/simulation/CapponiJITSequentialGame.s.sol` | ALIVE | V4-only simulation; no dependency on old reactive-integration or V1 FCI; uses `IFCIDeltaPlusReader` interface (duck-typed); will work with any FCI hook address |
| `foundry-script/simulation/JitGame.sol` | ALIVE | Simulation library; references `V3CallbackRouter` for V3 path (import present) but primarily consumed by `CapponiJITSequentialGame.s.sol` which only runs V4; vault interfaces are forward-looking |
| `foundry-script/types/Accounts.sol` | ALIVE | Pure wallet derivation utility; no contract coupling |
| `foundry-script/types/Context.sol` | ALIVE | Data struct; no contract coupling |
| `foundry-script/types/Protocol.sol` | ALIVE | Enum; no contract coupling |
| `foundry-script/types/Scenario.sol` | UNCERTAIN | Imports `V3CallbackRouter` from `@reactive-integration/adapters/uniswapV3/V3CallbackRouter.sol`; that contract still exists in `src/reactive-integration/` so it compiles, but V3 execution paths in this file drive the old adapter |
| `foundry-script/utils/Constants.sol` | ALIVE | Pure constants; no contract coupling |
| `foundry-script/utils/Deployments.sol` | UNCERTAIN (stale addresses) | Contains the current live deployment addresses for V2 flow AND stale addresses; see detail below |

---

## Detailed Findings

### DEAD files

#### `foundry-script/deploy/DeployFCIHookV4.s.sol`
- Imports `FeeConcentrationIndex` from `@fee-concentration-index/FeeConcentrationIndex.sol` (V1).
- Deploys V1 only. No reference to `FeeConcentrationIndexV2`, `NativeUniswapV4Facet`, or any V2 component.
- Superseded entirely by `DeployFci.s.sol` which deploys both.

#### `foundry-script/deploy/DeployReactiveAdapterV3.s.sol`
- Imports and deploys `ReactiveHookAdapter` from `@reactive-integration/adapters/uniswapV3/ReactiveHookAdapter.sol`.
- That contract lives in `src/reactive-integration/` — the old reactive layer superseded by `src/fee-concentration-index-v2/protocols/uniswap-v3/`.
- The V2 equivalent is `UniswapV3Reactive` + `UniswapV3Callback` + `UniswapV3Facet`.

#### `foundry-script/deploy/DeployV3CallbackRouter.s.sol`
- Deploys `V3CallbackRouter` from `@reactive-integration/adapters/uniswapV3/V3CallbackRouter.sol`.
- This router is part of the old reactive-integration adapter architecture, no longer needed in V2 flow.

#### `foundry-script/deploy/ApproveV3Router.s.sol`
- Calls `sepoliaV3CallbackRouter()` which returns `0x1284E9d71a87276d05abD860bD9990dce9Dd721E`.
- That is the old `V3CallbackRouter` deployment address (not in live V2 deployment table).
- No role in V2 system.

#### `foundry-script/deploy/CompareDeltaPlus.s.sol`
- Imports `ReactiveHookAdapter` from `@reactive-integration/`.
- Calls `sepoliaReactiveAdapter()` = `0xC1ED47e34E95fa74fCf0Ff9B4b75Dac99F1bFF23` (old adapter).
- The live V2 deployment table in MEMORY.md does not list `ReactiveHookAdapter`; V2 uses `UniswapV3Facet` / `UniswapV3Callback`.
- This comparison script is meaningless without a live old adapter that mirrors FCI state.

#### `foundry-script/reactive-integration/FeeConcentrationIndexBuilder.s.sol`
- Entirely built around `ReactiveHookAdapter` (old `src/reactive-integration/`).
- Uses `sepoliaReactiveAdapter()` = `0xC1ED47...` (old V3 adapter).
- All V3 scenario paths call through the old adapter's `getDeltaPlus()`.
- No awareness of FCI V2 or `UniswapV3Facet`.

#### `foundry-script/reactive-integration/run-differential.sh`
- Orchestrates deployment of `ReactiveHookAdapter` + `ThetaSwapReactive` from `src/reactive-integration/` (old).
- References `test/reactive-integration/uniswapV3/differential/FeeConcentrationIndexV4ReactiveV3.diff.t.sol` which is the old differential test.
- The entire flow (register pool on `ThetaSwapReactive`, wait for relay, verify via old adapter) is the superseded V1 reactive path.

---

### ALIVE files

#### `foundry-script/deploy/DeployFci.s.sol`
- Imports both `FeeConcentrationIndex` (V1) and `FeeConcentrationIndexV2`, plus `NativeUniswapV4Facet`.
- Deploys V1, V2, and wires the V4 facet to V2. This is the current authoritative deploy script.
- Lines 8-9: correct V2 imports from `@fee-concentration-index-v2/`.

#### `foundry-script/deploy/DeploySwapRouter.s.sol`
- Deploys `PoolSwapTest` (Uniswap V4 test router). No FCI coupling.

#### `foundry-script/deploy/DeployMockTokens.s.sol`
- Deploys mock ERC20s. No FCI coupling.

#### `foundry-script/simulation/CapponiJITSequentialGame.s.sol`
- V4-only fork simulation. Uses duck-typed `IFCIDeltaPlusReader` interface; decoupled from V1/V2.
- References `resolveDeployments()` for Unichain Sepolia V4 — valid for current infrastructure.

#### `foundry-script/simulation/JitGame.sol`
- Simulation library consumed by `CapponiJITSequentialGame.s.sol`.
- Imports `V3CallbackRouter` but the V3 paths are only triggered when `Protocol.UniswapV3` is passed; the game script always uses V4.
- `IVaultPokeSettle` interface is forward-looking (vault is still valid per CLAUDE.md).
- Compiles cleanly against current src.

#### `foundry-script/types/Accounts.sol`, `Context.sol`, `Protocol.sol`
- Pure data/utility files with no contract coupling.

#### `foundry-script/utils/Constants.sol`
- Pure numeric constants.

---

### UNCERTAIN files

#### `foundry-script/utils/Deployments.sol`
- **Stale addresses present**:
  - `sepoliaAdapter()` = `0xA4539EbBc31cd11b8b404D989507d3112F04cB45` — not in live V2 deployment table; likely an old V1 adapter.
  - `sepoliaFCI()` = `0xe24A74652067Ea5EF32Ee85d69Dc20d67E9220C0` — old V1 FCI address; not in live V2 deployment table.
  - `sepoliaReactiveAdapter()` = `0xC1ED47e34E95fa74fCf0Ff9B4b75Dac99F1bFF23` — old reactive adapter; MEMORY.md lists `ReactiveHookAdapter v3` = `0xF3B1023A4Ee10CB8F51E277899018Cd6D2836071` for the last known alive V3 adapter.
- **Current live addresses present**:
  - `sepoliaFreshV3Pool()` = `0xcB80f9b60627DF6915cc8D34F5d1EF11617b8Af8` — matches MEMORY.md.
  - `sepoliaCallbackProxy()` = `0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA` — matches MEMORY.md.
  - `lasnaThetaSwapReactive()` = `0x4072a68c549af7934296D57Fb3B834A9f11929d0` — present (V9 is `0x302adeea...` in MEMORY.md; this is an older entry).
- The `resolveV3()` function at line 180-191 returns stale `sepoliaAdapter()` and `sepoliaFCI()` — callers of `resolveV3()` get wrong addresses.
- **Recommendation**: Split into a `DeploymentsV2.sol` with only current V2 addresses, or update the stale entries. Do not delete the file — the current infra addresses (callback proxy, fresh pool, eth Sepolia V4 pool manager) are still needed.

#### `foundry-script/deploy/CreatePoolV3.s.sol`
- No FCI coupling. Creates a V3 pool on Sepolia. Reusable for V2 flow if a new pool is needed.
- Classified UNCERTAIN because it was designed for the old V1 differential test setup but has no hard dependency on V1.

#### `foundry-script/deploy/CreatePoolV4.s.sol`
- Uses `ethSepoliaFCIHook()` = `0xc3e8Cb062EC61b40530aBea9Df9449F5b95987C0` (line 96 of Deployments.sol).
- That address is listed as a V4 hook but it is unclear whether it is a V1 or V2 hook deployment. If it is V1, pool initialization would wire to the wrong hook.
- Needs verification that `ethSepoliaFCIHook()` points to a V2 `FeeConcentrationIndexV2` deployment.

#### `foundry-script/deploy/FundAccounts.s.sol`
- Calls `resolveV3(chainId)` on the SEPOLIA path (line 49), which returns stale `sepoliaAdapter()` + `sepoliaFCI()`.
- The V3 approval path approves tokens to the old `sepoliaV3Pool()` = `0xF66da9dd...` (original V1 pool, not the fresh V2 pool `0xcB80f9b6...`).
- Functional for V4 funding path; broken for V3 path.

#### `foundry-script/types/Scenario.sol`
- Imports `V3CallbackRouter` from `@reactive-integration/adapters/uniswapV3/V3CallbackRouter.sol`.
- That contract still exists in `src/reactive-integration/` so it compiles.
- V3 execution functions in this file (`burnPosition`, `executeSwap`, `mintPosition` V3 paths) use the old `V3CallbackRouter` pattern; they are not wired to the V2 `UniswapV3Facet`.
- Used by both `FeeConcentrationIndexBuilder.s.sol` (dead) and `JitGame.sol` (alive but V4-only).
- If a V3 scenario script is ever added for V2, this file needs updating. For current V4-only simulation use, it is harmless.

---

## Address Cross-Reference (Deployments.sol vs MEMORY.md)

| Function | Address in Deployments.sol | MEMORY.md / Live V2 | Match? |
|----------|---------------------------|---------------------|--------|
| `sepoliaFreshV3Pool()` | `0xcB80f9b60627DF6915cc8D34F5d1EF11617b8Af8` | `0xcB80f9b6...` (V3 Pool fee=3000) | YES |
| `sepoliaCallbackProxy()` | `0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA` | Callback Proxy | YES |
| `sepoliaReactiveAdapter()` | `0xC1ED47e34E95fa74fCf0Ff9B4b75Dac99F1bFF23` | ReactiveHookAdapter v3 = `0xF3B1023A...` | NO (stale) |
| `sepoliaAdapter()` | `0xA4539EbBc31cd11b8b404D989507d3112F04cB45` | Not in live V2 table | NO (stale) |
| `sepoliaFCI()` | `0xe24A74652067Ea5EF32Ee85d69Dc20d67E9220C0` | Not in live V2 table | NO (stale V1) |
| `lasnaThetaSwapReactive()` | `0x4072a68c549af7934296D57Fb3B834A9f11929d0` | ThetaSwapReactive v9 = `0x302adeea...` | NO (old entry) |

---

## Actionable Recommendations

1. **Delete immediately**: `DeployFCIHookV4.s.sol`, `DeployReactiveAdapterV3.s.sol`, `DeployV3CallbackRouter.s.sol`, `ApproveV3Router.s.sol` — all exclusively deploy or configure old reactive-integration components.

2. **Delete or archive**: `reactive-integration/FeeConcentrationIndexBuilder.s.sol`, `reactive-integration/run-differential.sh` — entire directory is the old V1 differential test infrastructure. Archive if the multi-phase recipe pattern is to be ported to V2.

3. **Delete**: `deploy/CompareDeltaPlus.s.sol` — comparison against old `ReactiveHookAdapter` is meaningless; V2 comparison should be written fresh against `UniswapV3Facet`.

4. **Update `Deployments.sol`**: Remove or clearly mark stale entries (`sepoliaAdapter`, `sepoliaFCI`, `sepoliaReactiveAdapter`, `lasnaThetaSwapReactive`). Add V2 live addresses from MEMORY.md. Fix `resolveV3()` to return V2 contracts or remove the function.

5. **Verify `ethSepoliaFCIHook()`**: Confirm whether `0xc3e8Cb062EC61b40530aBea9Df9449F5b95987C0` is a V1 or V2 deployment before using `CreatePoolV4.s.sol`.

6. **Keep as-is**: `DeployFci.s.sol`, `DeploySwapRouter.s.sol`, `DeployMockTokens.s.sol`, `CapponiJITSequentialGame.s.sol`, `JitGame.sol`, `types/Accounts.sol`, `types/Context.sol`, `types/Protocol.sol`, `utils/Constants.sol`.
