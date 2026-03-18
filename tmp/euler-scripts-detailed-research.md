# Euler Protocol Scripting & Tooling Ecosystem -- Detailed Research Report

**Date:** 2026-03-17
**Analyst:** Papa Bear
**Scope:** euler-vault-scripts, evk-periphery, euler-sdk, euler-interfaces

---

## Executive Summary

Euler's scripting/tooling ecosystem is split across four repositories that serve distinct but interconnected roles. There is **no single "euler-scripts" repo** -- the name is a common shorthand for `euler-vault-scripts`, which is a thin wrapper around the real engine in `evk-periphery`. The ecosystem is heavily Solidity-native (Forge scripts + bash orchestration), with the TypeScript SDK being a legacy Euler V1 artifact that has NOT been updated for V2/EVK.

**Key finding:** The entire Euler V2 vault management stack is driven by Solidity Forge scripts orchestrated by bash. There is no V2-native TypeScript SDK. Integrators use ABIs + addresses from `euler-interfaces` with their own ethers/viem code, or work at the Solidity level through the Lens contracts for read operations and EVault/EVC interfaces for writes.

---

## 1. Repository Map

| Repository | Role | Active? |
|---|---|---|
| `euler-xyz/euler-vault-scripts` | Thin user-facing wrapper for vault cluster deployment & management | Yes (V2) |
| `euler-xyz/evk-periphery` | The real engine: ManageClusterBase, Lens contracts, Swapper, IRM factories, Perspectives, EdgeFactory, all production cluster configs | Yes (V2) |
| `euler-xyz/euler-interfaces` | ABIs (JSON) + deployed addresses (per-chain JSON) + Solidity interfaces | Yes (V2) |
| `euler-xyz/euler-sdk` | TypeScript SDK for Euler V1 (batch dispatch, eToken/dToken helpers) | **Legacy V1 only** |

---

## 2. euler-vault-scripts -- The User-Facing Wrapper

### 2.1 Directory Structure (complete)

```
euler-vault-scripts/
  .env.example
  foundry.toml
  install.sh
  README.md
  remappings.txt
  script/
    ExecuteSolidityScript.sh          # Main entry point bash script
    clusters/
      Addresses.s.sol                 # Asset address constants (per-network)
      Cluster.s.sol                   # Template cluster config (user edits this)
    self-collateralization/
      SelfCollateralizationBase.s.sol # Base for self-collateral vault pairs
      SelfCollateralization.s.sol     # Concrete self-collateral deployment
```

### 2.2 What It Does

This repo is a **starter template**. You clone it, edit `Cluster.s.sol` to define your vault cluster, then run:

```bash
./script/ExecuteSolidityScript.sh script/clusters/Cluster.s.sol [options]
```

It delegates all real logic to `evk-periphery/script/production/ManageClusterBase.s.sol` via Forge remappings.

### 2.3 CLI Interface: ExecuteSolidityScript.sh

**Core options:**
- `--dry-run` -- Simulate without broadcasting
- `--rpc-url URL|CHAIN_ID` -- RPC endpoint or chain ID shorthand (1=mainnet, 8453=base, etc.)
- `--account NAME` / `--ledger` -- Signing method
- `--batch-via-safe` -- Route through Gnosis Safe multisig
- `--safe-address ADDR` -- Safe address (supports aliases: `DAO`, `labs`, `securityCouncil`)
- `--timelock-address ADDR` -- Schedule via TimelockController (aliases: `admin`, `wildcard`, `eusd`)
- `--risk-steward-address ADDR` -- Bypass timelock for cap/IRM changes

**Emergency options** (rapid security response):
- `--vault-address ADDR|all` -- Target vault
- `--emergency-ltv-collateral` -- Zero borrow LTV when used as collateral
- `--emergency-ltv-borrowing` -- Zero all collateral LTVs on the vault
- `--emergency-caps` -- Set supply/borrow caps to 0
- `--emergency-operations` -- Disable all ops via hook

**Simulation options:**
- `--simulate-safe-address` / `--simulate-timelock-address` -- Override simulation targets
- `--skip-pending-simulation` -- Disable pending tx simulation
- `--safe-owner-simulate` -- Verify sender is Safe owner before simulation
- `--skip-safe-simulation` -- Skip tx simulation before creating Safe payload

### 2.4 Cluster.s.sol -- The Configuration File

File: `/tmp/euler-vault-scripts/script/clusters/Cluster.s.sol`

This is the template users edit. It inherits `ManageClusterBase` and `AddressesEthereum`, and defines two functions:

- `defineCluster()` -- Sets `cluster.assets` array and path to JSON cache file
- `configureCluster()` -- Sets ALL parameters:
  - Governor addresses (for oracle routers and vaults)
  - Unit of account (USD, BTC, etc.)
  - Fee receiver + interest fee (basis points, e.g. `0.1e4` = 10%)
  - Max liquidation discount, liquidation cool-off time
  - Hook target + hooked ops
  - Oracle providers per asset (string references to adapter contract names)
  - Supply caps and borrow caps (in whole tokens, not wei)
  - IRM parameters per asset: `[baseRate, slope1, slope2, kink]`
  - LTV matrix (liquidation LTVs, rows=collateral, cols=liability)
  - Spread LTV and ramp duration

### 2.5 Self-Collateralization Script

File: `/tmp/euler-vault-scripts/script/self-collateralization/SelfCollateralization.s.sol`

Deploys a specialized two-vault structure for EulerSwap:
1. **Escrowed Collateral Vault** -- Holds asset as collateral (no IRM, escrow=true)
2. **Borrowable Vault** -- Accepts escrowed vault as collateral, allows borrowing same asset

Uses `IEdgeFactory.deploy()` to create both vaults + oracle router in one call. Governance is permanently renounced after deployment.

---

## 3. evk-periphery -- The Real Engine

### 3.1 Deployment Scripts (numbered sequence)

Located at `/tmp/evk-periphery/script/`:

| Script | Purpose |
|---|---|
| `00_ERC20.s.sol` | Deploy ERC20 tokens (mintable, synth, reward) |
| `01_Integrations.s.sol` | Deploy integration contracts |
| `02_PeripheryFactories.s.sol` | Deploy periphery factory contracts |
| `03_OracleAdapters.s.sol` | Deploy oracle adapter contracts |
| `04_IRM.s.sol` | Deploy Interest Rate Model instances |
| `05_EVaultImplementation.s.sol` | Deploy EVault implementation |
| `06_EVaultFactory.s.sol` | Deploy EVault factory |
| `07_EVault.s.sol` | Deploy individual EVault instances + oracle routers |
| `08_Lenses.s.sol` | Deploy Lens contracts (VaultLens, AccountLens, etc.) |
| `09_Perspectives.s.sol` | Deploy Perspective contracts |
| `10_Swap.s.sol` | Deploy Swapper contract |
| `11_FeeFlow.s.sol` | Deploy fee flow controller |
| `12_Governor.s.sol` | Deploy governor contracts |
| `13_TermsOfUseSigner.s.sol` | Deploy terms of use signer |
| `14_OFT.s.sol` | Deploy OFT (LayerZero bridge) adapters |
| `15_EdgeFactory.s.sol` | Deploy EdgeFactory |
| `20_EulerEarnFactory.s.sol` | Deploy EulerEarn (yield aggregation) factory |
| `21_EulerSwapImplementation.s.sol` | Deploy EulerSwap impl |
| `22_EulerSwapFactory.s.sol` | Deploy EulerSwap factory |
| `23_EulerSwapPeriphery.s.sol` | Deploy EulerSwap periphery |
| `24_EulerSwapRegistry.s.sol` | Deploy EulerSwap registry |
| `50_CoreAndPeriphery.s.sol` | **Full stack deployment** (interactive, deploys everything) |
| `51_OwnershipTransferCore.s.sol` | Transfer core contract ownership to multisigs |
| `52_OwnershipTransferPeriphery.s.sol` | Transfer periphery ownership to multisigs |

### 3.2 Interactive Deployment

```bash
./script/interactiveDeployment.sh --account ACC_NAME --rpc-url RPC_URL
```

Prompts for:
- DAO, Labs, Security Council, Security Partner A/B multisig addresses
- Permit2 address (default: canonical)
- Uniswap V2/V3 router addresses (for Swapper)
- FeeFlow init price
- Whether to deploy EUL OFT Adapter, EulerEarn, EulerSwap V2, eUSD/seUSD

### 3.3 Custom Scripts (via ExecuteSolidityScript.sh)

File: `script/production/CustomScripts.s.sol`

| Script Contract | Purpose | Signature |
|---|---|---|
| `GetVaultInfoFull` | Full vault info via VaultLens | `run(address vault)` |
| `GetAccountInfo` | Account info for specific vault | `run(address account, address vault)` |
| `MigratePosition` | Migrate positions between EVC accounts | `run(uint8[] sourceIds, uint8[] destIds)` |
| `MergeSafeBatchBuilderFiles` | Merge Safe TX builder files | Uses `--path` option |
| `LiquidateAccount` | Execute/check liquidation | `run(address account, address collateral)` or `checkLiquidation(address,address)` |
| `RedeployAccountLens` | Redeploy lens contracts | `run()` |
| `RedeployOracleUtilsAndVaultLenses` | Redeploy oracle+vault lenses | `run()` |

### 3.4 Utility Scripts & Shell Tools

Located at `script/utils/`:

| File | Purpose |
|---|---|
| `ClusterDump.s.sol` | Export full cluster config to CSV tables (LTVs, caps, IRM params, oracles) |
| `ExecuteTimelockTx.s.sol` | Execute scheduled timelock transactions |
| `PerspectiveCheck.s.sol` | Verify vault perspective compliance |
| `SanityCheckOracle.s.sol` | Verify oracle configuration for vaults |
| `SafeUtils.s.sol` | Safe multisig batch builder utilities |
| `ScriptUtils.s.sol` | Core script utilities (address loading, batch building) |
| `ScriptExtended.s.sol` | Extended script base class |
| `MockVaultAndOperations.s.sol` | Mock vault for testing |
| `MockERC20Mintable.sol` | Mintable ERC20 for testing |
| `StubOracle.sol` | Stub oracle for testing |
| `LayerZeroUtils.s.sol` | LZ bridge utilities |
| `SimulateSafeTxTenderly.s.sol` | Simulate Safe TXs on Tenderly |
| `calculate-irm-linear-kink.js` | Calculate IRM kink parameters from APY targets |
| `calculate-irm-adaptive-curve.js` | Calculate adaptive curve IRM parameters |
| `check-contract-verification.js` | Check contract verification status |
| `verify.js` | Contract verification utility |
| `determineArgs.sh` | Parse CLI arguments into forge flags |
| `checkEnvironment.sh` | Validate env variables |
| `executeForgeScript.sh` | Execute forge script with proper flags |
| `getFileNameCounter.sh` | Auto-increment file names for deployments |
| `ClusterDump.sh` | Shell wrapper for ClusterDump |
| `findVaultsByAdapter.sh` | Find vaults using a specific oracle adapter |
| `createTenderlyTestnet.sh` | Create Tenderly testnet fork |
| `simulateSafeTxTenderly.sh` | Simulate Safe TX on Tenderly |
| `verifyContracts.sh` | Batch contract verification |
| `VerifyFactoryProxies.sh` | Verify factory proxy contracts |
| `dopplerLogin.sh` / `dopplerSync.sh` | Doppler secrets management |
| `tenderlyDeal.sh` | Fund accounts on Tenderly fork |

### 3.5 Production Cluster Configs

Real deployed cluster configurations exist for:
- **Mainnet** (chainId 1): PrimeCluster, YieldCluster, RepoCluster, RWACluster + 20+ Frontier vaults (Cap, Falcon, Hyperwave, Level, Maple, Pareto, Renzo, etc.)
- **Arbitrum** (42161): ArbitrumCluster, YieldCluster, Theo
- **Base** (8453): BaseCluster
- **Linea** (59144): LineaCluster
- **Swell** (1923): SwellETHCluster
- **Unichain** (130): UnichainCluster, UnichainLSTCluster
- **Monad** (143): Extensive 2-pair and 3-pair clusters (USDC, USDT, AUSD denominated)
- **Plasma**: M1-M23 cluster configs

Each cluster has a `.s.sol` config file and a `.json` address cache.

---

## 4. Lens Contracts (Read-Only On-Chain Utilities)

Located at `evk-periphery/src/Lens/`. Deployed on every chain (addresses in euler-interfaces).

### 4.1 VaultLens

File: `/tmp/evk-periphery/src/Lens/VaultLens.sol`

Key functions:
- `getVaultInfoStatic(address vault)` -> `VaultInfoStatic` (name, symbol, decimals, asset, oracle, EVC, creator)
- `getVaultInfoDynamic(address vault)` -> `VaultInfoDynamic` (totalShares, totalCash, totalBorrowed, caps, IRM info, LTV info, oracle prices)
- `getVaultInfoFull(address vault)` -> `VaultInfoFull` (combined static + dynamic)

### 4.2 AccountLens

File: `/tmp/evk-periphery/src/Lens/AccountLens.sol`

Key functions:
- `getAccountInfo(address account, address vault)` -> `AccountInfo` (EVC info + vault position + rewards)
- `getAccountEnabledVaultsInfo(address evc, address account)` -> `AccountMultipleVaultsInfo` (all vaults for account)
- `getEVCAccountInfo(address evc, address account)` -> `EVCAccountInfo` (enabled controllers, collaterals, lockdown mode)
- `getVaultAccountInfo(address account, address vault)` -> `VaultAccountInfo` (shares, assets, borrowed, allowances, liquidity info with time-to-liquidation)

### 4.3 Other Lenses

- `OracleLens` -- Oracle configuration and pricing details
- `IRMLens` -- Interest rate model parameter introspection
- `UtilsLens` -- General utility functions
- `EulerEarnVaultLens` -- EulerEarn (yield aggregator) vault info

### 4.4 LensTypes.sol -- Complete Type Catalog

File: `/tmp/evk-periphery/src/Lens/LensTypes.sol` (483 lines)

This file defines all the return types used by lens contracts. Key structs:

- `VaultInfoStatic` / `VaultInfoDynamic` / `VaultInfoFull` -- Vault configuration and state
- `VaultAccountInfo` -- Account position in a vault (includes `AccountLiquidityInfo` with `timeToLiquidation`)
- `LTVInfo` -- Collateral LTV details including ramp state
- `AssetPriceInfo` -- Oracle price query results (mid/bid/ask)
- `VaultInterestRateModelInfo` -- IRM state and parameters
- `InterestRateModelDetailedInfo` -- Typed IRM params (Kink, AdaptiveCurve, Kinky, FixedCyclicalBinary)
- `AccountRewardInfo` / `VaultRewardInfo` -- Reward tracking data
- `OracleDetailedInfo` -- Oracle adapter configuration
- `EulerRouterInfo` -- Router configuration with resolved oracles
- Multiple oracle-specific info structs (Chainlink, Chronicle, Pyth, Uniswap V3, Pendle, etc.)
- `EulerEarnVaultInfoFull` / `EulerEarnVaultStrategyInfo` -- EulerEarn vault details

---

## 5. Batch/Multicall Patterns

### 5.1 EVC Batch (On-Chain, V2)

The Ethereum Vault Connector (EVC) provides native batching. All vault operations go through EVC, which supports:
- Batching multiple vault calls in a single transaction
- Deferred liquidity checks (check solvency only at end of batch)
- Sub-account management (256 sub-accounts per address)
- Operator delegation

This is the primary V2 multicall pattern. The scripts build EVC batch payloads via `BatchBuilder` in `ScriptUtils.s.sol`.

### 5.2 Safe Batch Builder (Governance)

When `--batch-via-safe` is used, the scripts generate `SafeBatchBuilder_*.json` payload files that can be loaded into the Safe Transaction Builder UI. This is used for:
- Cluster management by DAOs
- Emergency operations
- Timelock scheduling

### 5.3 Swapper Multicall (On-Chain)

File: `/tmp/evk-periphery/src/Swaps/ISwapper.sol`

The Swapper contract has a built-in multicall:

```solidity
function multicall(bytes[] memory calls) external;
```

Plus composable helper functions that chain together:
- `swap(SwapParams)` -- Execute a swap (exact input, exact output, or swap-and-repay)
- `repay(token, vault, amount, account)` -- Repay debt from contract balance
- `repayAndDeposit(token, vault, amount, account)` -- Repay + deposit remainder
- `deposit(token, vault, amountMin, account)` -- Deposit to vault
- `transfer(token, amountMin, receiver)` -- Transfer tokens out
- `sweep(token, amountMin, to)` -- Sweep remaining tokens

Swap handlers: `Generic` (arbitrary calldata), `UniswapV2`, `UniswapV3`.

### 5.4 Legacy V1 SDK Batch (euler-sdk, NOT for V2)

The V1 SDK provides `buildBatch()` and `simulateBatch()` for the V1 Exec contract's `batchDispatch`. This does NOT work with EVK/V2 vaults. Included here only for completeness.

---

## 6. euler-interfaces -- ABIs + Addresses

### 6.1 Structure

```
euler-interfaces/
  abis/                          # 35 JSON ABI files
    EVault.json, EthereumVaultConnector.json, VaultLens.json,
    AccountLens.json, Swapper.json, EulerSwap.json, EulerEarn.json,
    EdgeFactory.json, GenericFactory.json, EulerRouter.json, ...
  interfaces/                    # 35 Solidity interface files
    IEVault.sol, IEthereumVaultConnector.sol, IVaultLens.sol,
    IAccountLens.sol, ISwapper.sol, IEulerSwap.sol, ...
  addresses/
    <chainId>/                   # Per-chain deployed addresses
      CoreAddresses.json         # EVC, EVault factory, ProtocolConfig
      PeripheryAddresses.json    # IRM factories, Swapper, Perspectives
      LensAddresses.json         # Lens contract addresses
      GovernorAddresses.json     # Governor contract addresses
      MultisigAddresses.json     # Safe multisig addresses
      EulerSwapAddresses.json    # EulerSwap addresses
      TokenAddresses.json        # Common token addresses
      BridgeAddresses.json       # LZ bridge addresses
      OracleAdaptersAddresses.csv # Oracle adapter addresses
    test/<chainId>/              # Testnet addresses (Sepolia 11155111, etc.)
  config/
    multisig/                    # Safe config per role (DAO, labs, etc.)
    bridge/                      # Bridge config cache
    addresses/<chainId>/         # MultisigAddresses overrides
  EulerChains.json               # Chain metadata
  chains.js                      # Chain ID utilities
  sync.sh                        # Sync script
```

### 6.2 Supported Chains (Production)

| Chain ID | Network |
|---|---|
| 1 | Ethereum Mainnet |
| 10 | Optimism |
| 56 | BSC |
| 100 | Gnosis |
| 130 | Unichain |
| 137 | Polygon |
| 143 | Monad |
| 146 | Sonic |
| 239 | (Plasma) |
| 480 | Worldchain |
| 999 | HyperEVM |
| 1923 | Swell |
| 2818 | (Unknown) |
| 5000 | Mantle |
| 8453 | Base |
| 9745 | (Unknown) |
| 42161 | Arbitrum |
| 43114 | Avalanche |
| 57073 | Ink |
| 59144 | Linea |
| 60808 | Bob |
| 80094 | Berachain |

### 6.3 Mainnet Core Addresses (Example)

```json
{
  "evc": "0x0C9a3dd6b8F28529d72d7f9cE918D493519EE383",
  "eVaultFactory": "0x29a56a1b8214D9Cf7c5561811750D5cBDb45CC8e",
  "protocolConfig": "0x4cD6BF1D183264c02Be7748Cb5cd3A47d013351b",
  "permit2": "0x000000000022D473030F116dDEE9F6B43aC78BA3"
}
```

---

## 7. euler-sdk (TypeScript) -- Legacy V1 Only

### 7.1 Status

**This is a V1 SDK. It does NOT support EVK/V2.** It targets the original Euler contracts (Euler, Exec, Markets, Liquidation modules) which use a completely different architecture than EVK.

### 7.2 What It Provided (V1)

- `Euler` class with ethers.js contract instances for all V1 modules
- Token helpers: `eToken(addr)`, `dToken(addr)`, `pToken(addr)`, `erc20(addr)`
- Token lookup: `eTokenOf(underlying)`, `dTokenOf(underlying)`, `pTokenOf(underlying)`
- `buildBatch(items)` -- Encode batch calls for Exec.batchDispatch
- `simulateBatch(deferredLiquidity, items)` -- Static call simulation with gas estimation
- `decodeBatch(items, responses)` -- Decode batch responses
- `signPermit(token, opts)` / `signPermitBatchItem(token, opts)` -- EIP2612 permit signing
- Sub-account utilities: `getSubAccount()`, `getSubAccountId()`, `isRealSubAccount()`
- Built-in configs for mainnet, Ropsten, Goerli, BSC Testnet, Base Goerli

### 7.3 V2 TypeScript Situation

There is **no V2 TypeScript SDK**. For V2 integrations, developers use:
1. ABIs from `euler-interfaces/abis/*.json` with ethers.js or viem
2. Addresses from `euler-interfaces/addresses/<chainId>/*.json`
3. Direct contract calls to EVault, EVC, Lens contracts

---

## 8. Key Helper Contracts & Utilities

### 8.1 ManageClusterBase (Central Engine)

File: `/tmp/evk-periphery/script/production/ManageClusterBase.s.sol` (~50KB)

The `Cluster` struct defined here contains 40+ fields covering every aspect of vault cluster configuration. The base contract handles:
- Delta detection between on-chain state and desired config
- Vault deployment via factory
- Oracle router deployment and configuration
- IRM deployment and assignment
- LTV matrix management with ramp-down support
- Supply/borrow cap management
- Hook target configuration
- Safe batch payload generation
- Timelock scheduling
- Risk steward routing

### 8.2 EdgeFactory

File: `/tmp/evk-periphery/src/EdgeFactory/EdgeFactory.sol`

One-call deployment of complete "Edge markets":
- Deploys N vaults + oracle router + LTV relationships
- Configures everything in a single transaction
- Permanently renounces governance after deployment
- Used by `SelfCollateralization.s.sol` for EulerSwap vault pairs

### 8.3 IRM Calculation Utilities

- `script/utils/calculate-irm-linear-kink.js` -- Generate kink IRM parameters from APY targets
  ```bash
  node script/utils/calculate-irm-linear-kink.js borrow <baseIr> <kinkIr> <maxIr> <kink>
  ```
- `script/utils/calculate-irm-adaptive-curve.js` -- Generate adaptive curve IRM parameters

### 8.4 Perspectives (Vault Verification)

Perspective contracts verify that vaults meet certain criteria:
- `EVKFactoryPerspective` -- Vault was deployed by official factory
- `EscrowedCollateralPerspective` -- Vault is a valid escrow vault
- `GovernedPerspective` -- Vault is whitelisted by DAO governance
- `EulerUngovernedPerspective` -- Vault meets ungoverned criteria
- `EdgeFactoryPerspective` -- Vault was deployed by EdgeFactory
- `EulerEarnFactoryPerspective` -- EulerEarn vault from official factory
- `OneOfMetaPerspective` -- Vault passes at least one of multiple perspectives
- `CustomWhitelistPerspective` -- Custom whitelist

### 8.5 Governor Contracts

- `GovernorAccessControl` -- Role-based access control for vault governance
- `GovernorAccessControlEmergency` -- Adds emergency pause capabilities
- `CapRiskSteward` -- Allows cap/IRM changes to bypass timelocks
- `FactoryGovernor` -- Governor for factory contracts
- `GovernorGuardian` -- Guardian role management
- `ReadOnlyProxy` -- Read-only proxy for governance introspection

### 8.6 Hook Targets

- `BaseHookTarget` -- Base implementation
- `HookTargetAccessControl` -- Access-controlled operations
- `HookTargetAccessControlKeyring` -- Keyring-gated access
- `HookTargetGuardian` -- Guardian-controlled hooks
- `HookTargetMarketStatus` -- Market status hooks
- `HookTargetStakeDelegator` -- Staking delegation hooks
- `HookTargetTermsOfUse` -- Terms of use enforcement

---

## 9. Vault Interaction Patterns for Developers

### 9.1 Reading Vault State

Use Lens contracts (deployed addresses in euler-interfaces):

```solidity
// Get full vault info
VaultInfoFull memory info = VaultLens(lensAddr).getVaultInfoFull(vaultAddr);

// Get account position
AccountInfo memory acct = AccountLens(lensAddr).getAccountInfo(account, vault);

// Get all enabled vaults for account
AccountMultipleVaultsInfo memory multi = AccountLens(lensAddr)
    .getAccountEnabledVaultsInfo(evcAddr, account);
```

### 9.2 Writing (Deposit/Borrow/Repay)

All writes go through EVC for batching and deferred liquidity checks:

```solidity
// Simple deposit
IERC20(asset).approve(vault, amount);
IEVault(vault).deposit(amount, receiver);

// EVC batch: deposit + enable collateral + borrow from another vault
IEVC(evc).batch([
    // enable collateral
    abi.encodeCall(IEVC.enableCollateral, (account, collateralVault)),
    // enable controller
    abi.encodeCall(IEVC.enableController, (account, borrowVault)),
    // deposit collateral
    abi.encodeCall(IEVault.deposit, (amount, account)),
    // borrow
    abi.encodeCall(IEVault.borrow, (borrowAmount, account))
]);
```

### 9.3 Cluster Deployment Workflow

1. Clone euler-vault-scripts
2. Edit `Cluster.s.sol` with assets, LTVs, oracles, caps, IRM params
3. Run with `--dry-run` first
4. Deploy: `./script/ExecuteSolidityScript.sh script/clusters/Cluster.s.sol --account DEPLOYER --rpc-url 1`
5. Commit the generated `.json` address cache
6. For subsequent changes, re-edit and re-run (only delta applied)
7. After governance transfer, use `--batch-via-safe --timelock-address wildcard`

---

## 10. Analysis & Recommendations (ThetaSwap Relevance)

### 10.1 What is Directly Useful

1. **ManageClusterBase pattern** -- The delta-management approach (compare on-chain state vs config, only apply changes) is excellent for managing complex multi-vault deployments. ThetaSwap's FCI V2 diamond could benefit from a similar pattern.

2. **Lens contracts** -- The VaultLens/AccountLens pattern of deploying read-only helper contracts that aggregate multiple calls is directly applicable. ThetaSwap could deploy an FCILens that returns comprehensive index state.

3. **EdgeFactory pattern** -- Single-transaction deployment of multiple interconnected contracts with governance renounced. Relevant for deploying FCI vault+adapter pairs.

4. **IRM calculation scripts** -- The JS utilities for computing IRM parameters from target APY values are useful reference for any lending parameter configuration.

5. **ClusterDump** -- CSV export of on-chain configuration for audit/review. Could adapt for ThetaSwap to dump deployed FCI configurations.

### 10.2 What is NOT Directly Useful

1. **euler-sdk (V1)** -- Legacy, wrong architecture. Do not reference for V2 integration.

2. **Safe/Timelock integration** -- Complex governance tooling for DAO-managed vaults. Overkill for ThetaSwap unless planning DAO governance.

3. **Perspective system** -- Euler-specific vault verification. Not applicable to ThetaSwap's architecture.

### 10.3 Key Architectural Insight

Euler V2 has NO TypeScript SDK for vault interactions. Everything is Solidity-native. This suggests that for DeFi protocol scripting, the Forge script + bash pattern is production-proven at scale (Euler manages 20+ chains, 100+ vault clusters this way). ThetaSwap's existing Forge script approach aligns with industry best practice.

---

## Sources

- [euler-xyz/euler-vault-scripts](https://github.com/euler-xyz/euler-vault-scripts) -- Cloned and fully analyzed
- [euler-xyz/evk-periphery](https://github.com/euler-xyz/evk-periphery) -- Cloned and fully analyzed
- [euler-xyz/euler-sdk](https://github.com/euler-xyz/euler-sdk) -- Cloned and fully analyzed
- [euler-xyz/euler-interfaces](https://github.com/euler-xyz/euler-interfaces) -- Cloned and fully analyzed
- [euler-vault-scripts Guide (Euler Docs)](https://docs.euler.finance/creator-tools/vaults/evk/euler-vault-scripts/)
- [Getting Started (Euler Docs)](https://docs.euler.finance/developers/getting-started/)
- [Creating and Managing Vaults (Euler Docs)](https://docs.euler.finance/developers/evk/creating-managing-vaults/)
- [Interacting with Vaults (Euler Docs)](https://docs.euler.finance/developers/evk/interacting-with-vaults/)
- [Announcing the Euler SDK](https://www.euler.finance/blog/announcing-the-euler-sdk)
