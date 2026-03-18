# Euler Finance Vault Architecture & DX Research

**Purpose**: Identify patterns from Euler's vault ecosystem that ThetaSwap can adopt for its FCI Token Vault client interfaces.

**Date**: 2026-03-17

**Note**: Findings based on comprehensive knowledge of Euler's public repositories and documentation (euler-xyz/euler-vault-kit, euler-xyz/evk-periphery, euler-xyz/euler-earn, Euler V2 whitepaper) through May 2025.

---

## Executive Summary

Euler V2 is built around two core primitives: the **Euler Vault Kit (EVK)** for lending/borrowing vaults and **Euler Earn** for yield aggregation meta-vaults. Both are ERC-4626 compliant with significant extensions. The architecture provides strong patterns ThetaSwap can adopt:

1. **Lens/Peripheral contracts** that batch-read vault state in a single call
2. **Simulation/preview functions** beyond ERC-4626's `previewDeposit`/`previewRedeem`
3. **Modular vault construction** via compile-time module inheritance (storage isolation principles apply to ThetaSwap's diamond)
4. **Rich event design** for indexer consumption
5. **Batch operation patterns** via the Ethereum Vault Connector (EVC)

The most directly applicable patterns for ThetaSwap's FCI vault are: (a) the **VaultLens** aggregator contract, (b) the **account status check** pattern, and (c) the **simulation framework**.

---

## 1. Euler Vault Kit (EVK) Architecture

### 1.1 Core Vault Structure

EVK vaults use a module-based architecture where each vault is a single deployed contract that internally dispatches to modules via `delegatecall`. The key modules:

| Module | Responsibility |
|--------|---------------|
| `Vault` | ERC-4626 deposit/withdraw/mint/redeem |
| `Borrowing` | Borrow/repay logic |
| `Liquidation` | Liquidation triggers and execution |
| `Governance` | Parameter setting (LTV, caps, IRM) |
| `BalanceForwarder` | Reward token tracking delegation |
| `Initialize` | One-time setup |
| `Token` | ERC-20 share token logic |
| `RiskManager` | Account health checks |

Modules share a `Base` storage contract with a single storage struct at a fixed slot -- similar to diamond storage but linked at compile time rather than via separate facet deployments.

### 1.2 View Functions Exposed

EVK vaults expose an extensive set of view functions beyond standard ERC-4626:

**Standard ERC-4626 Views**: `totalAssets()`, `convertToShares/Assets()`, `maxDeposit/Mint/Withdraw/Redeem()`, `previewDeposit/Mint/Withdraw/Redeem()`.

**Euler-Specific Extensions**:

```solidity
// Vault configuration
function asset() external view returns (address);
function unitOfAccount() external view returns (address);
function oracle() external view returns (address);
function interestRateModel() external view returns (address);
function creator() external view returns (address);

// Supply/borrow accounting
function totalBorrows() external view returns (uint256);
function cash() external view returns (uint256);
function interestAccumulator() external view returns (uint256);

// Risk parameters
function LTVFull(address collateral) external view returns (
    uint16 borrowLTV, uint16 liquidationLTV,
    uint16 initialLiquidationLTV, uint48 targetTimestamp, uint32 rampDuration
);
function caps() external view returns (uint16 supplyCap, uint16 borrowCap);

// Per-account state
function debtOf(address account) external view returns (uint256);
function accountLiquidityFull(address account, bool liquidation) external view returns (
    address[] memory collaterals, uint256[] memory collateralValues, uint256 liabilityValue
);

// Hooks configuration
function hookConfig() external view returns (address hookTarget, uint32 hookedOps);
function interestRate() external view returns (uint256);
```

**Key insight for ThetaSwap**: `accountLiquidityFull` returns a complete per-collateral breakdown in a single call. This pattern -- a single view that returns the full position decomposition -- is extremely valuable for frontends.

### 1.3 Vault Metadata Convention

Configuration is exposed through individual getters, but the **VaultLens** peripheral aggregates them into a single struct. The metadata follows:
- **Immutable config** (asset, unitOfAccount, creator): set at initialization
- **Governable config** (oracle, IRM, LTVs, caps, hook config): changeable by governor
- **Dynamic state** (totalBorrows, cash, interestAccumulator): updated on every interaction

### 1.4 Simulation / Preview Functions

Beyond standard ERC-4626 previews, EVK provides `checkAccountStatus(account)` and `checkLiquidation(liquidator, violator, collateral)`. The EVC adds `batchSimulation(BatchItem[] items)` which executes operations in a simulated context via `eth_call`, returning results without committing state. This lets frontends simulate multi-step operations like "deposit collateral, borrow, swap" in a single RPC call.

---

## 2. Euler Earn (Meta-Vault / Yield Aggregator)

Euler Earn is a meta-vault that deposits into multiple EVK vaults. It is itself ERC-4626 compliant. Key patterns:

- **Strategy views**: `getStrategy(strategy)` returns `(allocated, allocationPoints, status, cap)`; `getStrategies()` returns the full list
- **Two-phase allocation**: Deposits go to cash first; a keeper calls `rebalance(strategy, targetAllocation)` separately
- **Performance fee via share minting**: On `harvest()`, if assets grew, fee shares are minted to the fee recipient rather than skimming underlying assets. This is the standard ERC-4626 fee pattern ThetaSwap should adopt.

---

## 3. Peripheral / Lens Contracts (evk-periphery)

### 3.1 VaultLens -- The Most Important Pattern

The `VaultLens` aggregates all vault state into a single struct:

```solidity
struct VaultInfoFull {
    address vault; string vaultName; string vaultSymbol; uint8 vaultDecimals;
    address asset; string assetName; string assetSymbol; uint8 assetDecimals;
    address unitOfAccount; string unitOfAccountName; string unitOfAccountSymbol; uint8 unitOfAccountDecimals;
    uint256 totalShares; uint256 totalCash; uint256 totalBorrowed; uint256 totalAssets;
    uint256 accumulatedInterest; uint256 interestAccumulator; uint256 interestRate;
    address oracle; address irm; address creator; address governorAdmin;
    uint16 supplyCap; uint16 borrowCap; uint16 interestFee;
    address hookTarget; uint32 hookedOps;
    LTVInfo[] ltvInfo;
    uint256 maxDeposit; uint256 maxMint; uint256 maxWithdraw; uint256 maxRedeem;
    uint256 timestamp;
}

function getVaultInfoFull(address vault) external view returns (VaultInfoFull memory);
function getVaultInfoFull(address[] calldata vaults) external view returns (VaultInfoFull[] memory);
```

It makes individual `staticcall` per getter, each wrapped in try/catch. A failing getter returns zero/empty rather than reverting the entire read. This resilience is critical.

### 3.2 AccountLens

```solidity
struct AccountInfo {
    address vault; address account;
    uint256 shares; uint256 assets; uint256 borrowed;
    uint256 collateralValue; uint256 liabilityValue; bool isHealthy;
    uint256 assetAllowance; uint256 assetBalance;  // wallet data included!
}
```

Including `assetBalance` and `assetAllowance` saves the frontend from making separate ERC-20 calls. ThetaSwap should absolutely adopt this.

### 3.3 OracleLens -- Error Message Forwarding

```solidity
struct OracleInfo {
    address oracle; address base; address quote;
    uint256 price; bool valid;
    string error;  // revert reason captured as string
}
```

Capturing the revert reason and surfacing it as a string field is a notable DX pattern. Frontends can display "Oracle: stale price (last update 3600s ago)" instead of "call reverted."

### 3.4 UtilsLens

Computed convenience values: `computeExchangeRate(vault)`, `computeAPY(vault)` returning both supply and borrow APY, `getTokenPrice(vault, token)`.

---

## 4. Developer Experience Tooling

### 4.1 Batch Operations via EVC

The Ethereum Vault Connector is the central router supporting batched operations:

```solidity
struct BatchItem {
    address targetContract; address onBehalfOfAccount; uint256 value; bytes data;
}
function batch(BatchItem[] calldata items) external;
```

Scripts compose multi-step operations (deposit + enable collateral + borrow) in a single transaction.

### 4.2 Factory + Event Discovery

Euler uses `GenericFactory.createProxy()` emitting `ProxyCreated(proxy, implementation)` events. There is no on-chain registry -- frontends discover vaults by scanning factory events, then batch-read state via VaultLens. This is lightweight but requires an indexer.

### 4.3 Immutable Args in Proxy Bytecode

`GenericFactory.createProxy(implementation, upgradeable, trailingData)` embeds immutable configuration into the proxy bytecode, accessible via `CODECOPY` instead of SLOAD. Saves ~2100 gas per read for frequently-accessed parameters.

### 4.4 TypeScript SDK

The `@euler-xyz/euler-sdk` wraps lens contracts with multicall batching, simulation via `eth_call` with state overrides, event-based vault discovery, and human-readable error formatting.

---

## 5. ERC-4626 Compliance and Extensions

### 5.1 Compliance Details

- `totalAssets()` returns `cash + totalBorrows - accruedFees`
- `maxWithdraw/Redeem` returns `min(userShares, cash)` -- limited by available liquidity
- Exchange rate is monotonically increasing

### 5.2 Extensions Beyond Standard

| Extension | Purpose |
|-----------|---------|
| `skim()` | Donation attack protection |
| `debtOf(account)` | Debt tracking |
| `pullDebt(from, amount)` | Debt migration |
| `flashLoan(amount, data)` | Flash loans |
| `touch()` | Force interest accrual |
| `convertToAssetsUp/Down` | Rounding-direction-aware conversion |

### 5.3 Rounding Conventions

Strictly follows ERC-4626: round down for `convertToShares`/`previewDeposit`/`previewRedeem`, round up for `convertToAssets`/`previewMint`/`previewWithdraw`. Always favor the vault. For ThetaSwap, this is critical for MEV protection when FCI value is derived from pool state.

---

## 6. Event Design for Indexing

### 6.1 Design Principles

1. **All governance changes emit separate events** with new values -- enables parameter history reconstruction from logs alone
2. **Financial events include both assets and shares** -- indexers compute exchange rates without extra calls
3. **`InterestAccrued` emitted on every state change** -- exact accumulator trajectory reconstruction
4. **`indexed` on addresses, not amounts** -- correct filtering trade-off
5. **`VaultStatus` periodic snapshots** -- indexers bootstrap from recent state rather than replaying from genesis

---

## 7. Applicable Patterns for ThetaSwap FCI Vault

### 7.1 FCIVaultLens (Priority 1 -- Highest Impact)

```solidity
struct FCIVaultState {
    // Vault identity
    address vault;
    // Collateral
    address collateralToken;
    uint128 totalDeposits;
    uint128 depositCap;
    // Oracle payoff (Model B)
    uint160 sqrtPriceStrike;
    uint160 sqrtPriceHWM;
    uint256 expiry;
    bool settled;
    uint256 longPayoutPerToken;  // Q96
    // Token IDs
    uint256 longTokenId;
    uint256 shortTokenId;
    // ERC-20 wrapper addresses
    address longWrapper;
    address shortWrapper;
    // Supplies
    uint256 longTotalSupply;
    uint256 shortTotalSupply;
    // Timestamp
    uint256 timestamp;
}

function getVaultState(address vault) external view returns (FCIVaultState memory);
```

### 7.2 FCIAccountLens (Priority 1)

```solidity
struct FCIAccountInfo {
    address vault;
    address account;
    // ERC-6909 balances
    uint256 longBalance6909;
    uint256 shortBalance6909;
    // ERC-20 wrapped balances
    uint256 longBalanceERC20;
    uint256 shortBalanceERC20;
    // Wallet state (saves frontend extra calls)
    uint256 collateralBalance;
    uint256 collateralAllowance;
    // Previews (if settled)
    uint256 longPayout;
    uint256 shortPayout;
}

function getAccountInfo(address vault, address account) external view returns (FCIAccountInfo memory);
```

### 7.3 Try/Catch Resilient Reads

Every field read in the lens independently try/caught:
```solidity
function _tryGetAsset(address vault) internal view returns (address) {
    try IEVault(vault).asset() returns (address a) { return a; } catch { return address(0); }
}
```

### 7.4 Error Message Forwarding

```solidity
function _tryGetPrice(address oracle, address base, address quote)
    internal view returns (uint256 price, bool valid, string memory error)
{
    try IOracle(oracle).getQuote(1e18, base, quote) returns (uint256 p) {
        return (p, true, "");
    } catch Error(string memory reason) {
        return (0, false, reason);
    } catch (bytes memory lowLevelData) {
        return (0, false, string(abi.encodePacked("low-level: 0x", _toHex(lowLevelData))));
    }
}
```

---

## 8. Key Differences: Euler vs ThetaSwap

| Aspect | Euler EVK | ThetaSwap FCI Vault |
|--------|-----------|---------------------|
| Underlying | ERC-20 tokens (lending) | Uniswap V3/V4 fee concentration |
| Value accrual | Interest from borrowers | HWM-tracked FCI payoff |
| Token model | Single share token | Dual LONG/SHORT (ERC-6909 + ERC-20 wrappers) |
| Settlement | Continuous (no expiry) | Expiry-based settlement |
| External dependency | Oracle + IRM | FCI oracle + Reactive Network |
| Update mechanism | Interest accrual on interaction | Permissionless poke() + reactive callbacks |

---

## 9. Implementation Priority Order

| Priority | Pattern | Complexity | Impact |
|----------|---------|-----------|--------|
| 1 | VaultLens + AccountLens | ~200 LOC | Very High |
| 2 | Vault metadata view functions (on-chain) | ~80 LOC | Very High |
| 3 | Live payoff preview (pre-settlement) | ~50 LOC | High |
| 4 | Event schema enrichment | ~50 LOC | High |
| 5 | Error message propagation in lens | ~50 LOC | Medium |
| 6 | Router for composed operations | ~200 LOC | Medium |

Lens contracts first (immediate frontend enablement), then on-chain views (CLI/script support), then events (indexer support).

---

## 10. Repository References

- `github.com/euler-xyz/euler-vault-kit` -- Core vault, modules, interfaces
- `github.com/euler-xyz/evk-periphery` -- VaultLens, AccountLens, OracleLens, scripts
- `github.com/euler-xyz/ethereum-vault-connector` -- EVC batch/simulation
- `github.com/euler-xyz/euler-earn` -- Meta-vault, yield aggregation
- `github.com/euler-xyz/euler-interfaces` -- All interface definitions
- `github.com/euler-xyz/euler-price-oracle` -- Oracle adapters
