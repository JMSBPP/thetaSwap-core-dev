# Research Data Audit Report

**Date**: 2026-03-17
**Branch**: 008-uniswap-v3-reactive-integration
**Auditor**: Papa Bear (Claude Opus 4.6)

---

## Executive Summary

The `research/` folder contains a tightly integrated data pipeline spanning Dune SQL queries, Uniswap V3 subgraph queries, Python econometrics modules, backtest simulations, oracle scripts, and Jupyter notebooks. The data architecture has **two distinct layers**:

1. **Static/frozen data**: All empirical data from Dune and subgraph queries is hardcoded into Python source files (`econometrics/data.py`, `econometrics/cross_pool/data.py`, `econometrics/per_position_data.py`) and JSON fixture files. No runtime Dune/subgraph calls occur during normal operation.

2. **Derived/computed data**: Oracle scripts transform raw event JSON into test fixtures. Econometrics modules consume hardcoded data to run statistical models. Backtest modules consume econometrics data to run insurance simulations.

**Key finding**: The data is frozen as of 2026-03-05. All queries are preserved for reproducibility but the hardcoded values are the actual source of truth for all downstream analysis.

---

## 1. All Data Files

### 1.1 Fixture Files

| File | Size | Content | Type |
|------|------|---------|------|
| `research/data/fixtures/fci_weth_usdc_v4.json` | 42K | WETH/USDC V4 pool events (107 events) + 4 FCI snapshots. Pool ID `0x4f88...`, block range 23656000-23668000, forkBlock 23655999. Contains Swap and ModifyLiquidity events with expected FCI values at snapshot blocks. | **Generated** by `data/scripts/fci_oracle.py` from raw events |

### 1.2 Raw Event Files

| File | Size | Content | Type |
|------|------|---------|------|
| `research/data/raw/fci_weth_usdc_v4_events.json` | 33K | Same pool events as fixture but with additional metadata (blockRange, duneQueryId: 6795594). The source input for the oracle. Contains Swap + ModifyLiquidity events with sqrtPriceX96, tick bounds, liquidityDelta, salt. | **Fetched from Dune** query 6795594, then stored statically |

### 1.3 Econometrics Result Files

| File | Size | Content | Type |
|------|------|---------|------|
| `research/data/econometrics/estimation_result.json` | 370B | Structural logit output: beta_concentration=-0.175, p=2.96e-7, n=91, pseudo_R2=0.359, WTP=5.49e-7 | **Computed** by `econometrics/estimate.py` |
| `research/data/econometrics/estimation_result_lagged.json` | 2.5K | Five logit specs (Contemporaneous, Lag-1, 3-day MA, 7-day MA, Cumulative Max) + predictive spec. 7-day MA is best (pseudo_R2=0.393) | **Computed** by estimation pipeline |
| `research/data/econometrics/duration_result.json` | 504B | Duration model: beta_a_t=10.07 (p=0.0), beta_il=-11.61 (p=0.050), n=191, R2=0.644, mean blocklife=306 hours | **Computed** by `econometrics/run_duration.py`, written to line 26-27 |

### 1.4 Hardcoded Data in Python Source Files

#### `research/econometrics/data.py` (lines 1-342)
**This is the central data hub.** Three hardcoded datasets:

| Variable | Lines | Records | Source | Content |
|----------|-------|---------|--------|---------|
| `IL_MAP` | 11-26 | 41 days | Dune Q5 | day -> IL proxy, 2025-12-05 to 2026-01-14 |
| `RAW_POSITIONS` | 30-249 | 600 tuples | Dune Q4v2 (6 paginated batches) | (burn_date, blocklife, exit_day_a_t) |
| `DAILY_AT_MAP` | 254-296 | 41 days | Dune query 6783604 | day -> real A_T = sqrt(sum(theta_k * x_k^2)) |
| `DAILY_AT_NULL_MAP` | 300-342 | 41 days | Dune query 6783604 | day -> null A_T = sqrt(sum(theta_k)/N^2) |

#### `research/econometrics/cross_pool/data.py` (lines 1-45)

| Variable | Lines | Records | Source | Content |
|----------|-------|---------|--------|---------|
| `SELECTED_POOLS` | 13-27 | 10 pools | V3 subgraph top-100 by TVL, 2-4-4 stratification | Pool addresses, symbols, fee tiers, TVL, volume, category |
| `POOL_CONCENTRATIONS` | 31-45 | 10 entries | Dune query 6784588 (90-day window) | a_t, a_t_null, delta_plus, n_positions per pool |

#### `research/econometrics/per_position_data.py` (lines 1-82)

| Variable | Lines | Records | Source | Content |
|----------|-------|---------|--------|---------|
| `PER_POSITION_DATA` | 25-81 | 50 tuples | Dune query 6815916 | (burn_date, block_lifetime, fee_share_x_k, token_id) for ETH/USDC 0.3%, Dec 20-26 2025 |

---

## 2. All Query Files

### 2.1 Dune SQL Queries

| File | Dune ID | Pool | Purpose | Cost |
|------|---------|------|---------|------|
| `data/queries/fci_weth_usdc_v4.sql` | 6795594 | WETH/USDC V4 5bps | Balanced event stream: all ModifyLiquidity + sampled swaps, block range 23656000-23668000 | Unknown |
| `data/queries/dune/fci_v3_weth_usdc_events.sql` | N/A (parameterized) | ETH/USDC V3 500bps (0x88e6...) | V3 Swap+Mint+Burn+Collect events for FCI shadow oracle | Parameterized |
| `data/queries/dune/6783604-daily-at-per-position.sql` | 6783604 | ETH/USDC 30bps (0x8ad5...) | Daily real A_T and null A_T from position-level fees. Window: 2025-12-05 to 2026-01-14 (41 days) | ~0.386 credits |
| `data/queries/dune/6784588-cross-pool-at.sql` | 6784588 | Parameterized (10 pools) | Aggregate A_T per pool over 90-day window. Returns single row with A_T, A_T_null, delta_plus | ~0.3 credits/pool |
| `data/queries/dune/per_position_fee_shares_dec2025.sql` | 6815894 | ETH/USDC 0.3% | ~50 positions exiting Dec 20-26. fee_share_x_k uses total Collect (principal+fees proxy) | 0.107 credits |
| `data/queries/dune/per_position_fees_only_dec2025.sql` | 6815901 | ETH/USDC 0.3% | Refined: fee = Collect - Decrease at exit tx only. Problem: 54% zero fees | 0.075 credits |
| `data/queries/dune/per_position_lifetime_fees_dec2025.sql` | 6815916 | ETH/USDC 0.3% | Final: ALL lifetime Collects - ALL lifetime Decreases. x_k range 0-0.548 | 0.111 credits |

### 2.2 Subgraph Queries

| File | Endpoint | Purpose |
|------|----------|---------|
| `data/queries/subgraph/pool-discovery.graphql` | Uniswap V3 Subgraph (The Graph) | Top 100 pools by TVL (volume > $1M) for cross-pool stratification |

### 2.3 Data-Fetching Code

| File | Lines | Protocol | Runtime Behavior |
|------|-------|----------|-----------------|
| `econometrics/cross_pool/subgraph.py` | 45-66 | The Graph HTTP API | `fetch_top_pools()` makes live HTTP request. Requires `GRAPH_API_KEY` env var. **Not called during normal operation** -- results frozen in `cross_pool/data.py` |

---

## 3. Data Flow Mapping

### 3.1 Primary Data Flow

```
Dune queries (SQL)
  |
  v
Dune MCP extractions (manual sessions)
  |
  v
econometrics/data.py (HARDCODED: RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP)
  |
  +---> econometrics/ingest.py (build_lagged_positions, build_exit_panel, build_exit_panel_deviation)
  |       |
  |       +---> econometrics/duration.py (duration_model_robust) --> data/econometrics/duration_result.json
  |       |
  |       +---> econometrics/hazard.py (logit_mle, logit_mle_quadratic) --> data/econometrics/estimation_result*.json
  |       |
  |       +---> econometrics/estimate.py (structural_logit)
  |
  +---> backtest/daily.py (build_daily_states)
  |       |
  |       +---> backtest/payoff.py (run_exit_payoff_backtest)
  |       +---> backtest/pnl.py (compute_position_pnl)
  |       +---> backtest/mechanism_sweep.py (run_mechanism_sweep, run_payoff_comparison)
  |
  +---> backtest/oracle_comparison.py (positions_from_raw_data, build_dual_series)
  |       |
  |       +---> backtest/synthetic_exits.py (build_from_raw_positions)
  |
  +---> notebooks/* (all 5 notebooks)
```

### 3.2 Cross-Pool Data Flow

```
subgraph/pool-discovery.graphql
  |
  v
econometrics/cross_pool/subgraph.py (fetch_top_pools, select_pools)
  |
  v [results frozen]
econometrics/cross_pool/data.py (HARDCODED: SELECTED_POOLS, POOL_CONCENTRATIONS)
  |
  +---> econometrics/cross_pool/analysis.py (summary_table, scatter plots, architecture_decision)
  +---> notebooks/cross-pool-concentration-severity.ipynb
```

### 3.3 FCI Oracle Data Flow (Solidity Test Support)

```
Dune query 6795594 (V4 events)
  |
  v
data/raw/fci_weth_usdc_v4_events.json  (33K, stored statically)
  |
  v
data/scripts/fci_oracle.py:357-393  (replays FCI math, generates snapshots)
  |
  v
data/fixtures/fci_weth_usdc_v4.json  (42K, events + 4 snapshots with expected values)
  |
  v
test/fee-concentration-index/differential/FeeConcentrationIndexPythonFFI.diff.fork.t.sol:87
  (Solidity fork test reads via vm.readFile)
```

### 3.4 Import Dependency Map (Econometrics Modules)

| Module | Imports Data From | Key Functions |
|--------|------------------|---------------|
| `econometrics/types.py` | None (pure types) | DailyPanelRow, PositionRow, EstimationResult, DurationResult, etc. |
| `econometrics/data.py` | None (hardcoded data source) | IL_MAP, RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP |
| `econometrics/ingest.py` | `econometrics.types` | ingest_daily_panel, ingest_positions, build_lagged_positions, build_exit_panel, build_exit_panel_deviation, build_exit_panel_lifetime_mean |
| `econometrics/estimate.py` | `econometrics.types` | structural_logit (JAX-based) |
| `econometrics/duration.py` | `econometrics.ingest`, `econometrics.types` | duration_model_robust, sensitivity_sweep (JAX-based) |
| `econometrics/hazard.py` | `econometrics.ingest`, `econometrics.types` | logit_mle, logit_mle_quadratic, marginal_effect_at_means (JAX-based) |
| `econometrics/per_position_data.py` | None (hardcoded) | PER_POSITION_DATA |
| `econometrics/run_duration.py` | `econometrics.data`, `econometrics.duration`, `econometrics.ingest` | CLI runner, writes duration_result.json |
| `econometrics/cross_pool/types.py` | None (pure types) | PoolInfo, PoolConcentration, CollectEvent |
| `econometrics/cross_pool/data.py` | `cross_pool.types` | SELECTED_POOLS, POOL_CONCENTRATIONS |
| `econometrics/cross_pool/subgraph.py` | `cross_pool.types` | fetch_top_pools (live HTTP), select_pools |
| `econometrics/cross_pool/analysis.py` | `cross_pool.types` | spearman_rank, summary_table, scatter plots, architecture_decision |

---

## 4. Backtest Data Dependencies

The `research/backtest/` module (8 files) consumes data exclusively from `econometrics/data.py`:

| Backtest Module | Data Consumed | Via |
|----------------|---------------|-----|
| `backtest/daily.py` | DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP, RAW_POSITIONS | Direct args from callers |
| `backtest/payoff.py` | DailyPoolState list, raw_positions dicts | Built by `daily.py` |
| `backtest/pnl.py` | DailyPoolState dict, ReserveState dict | Built by callers |
| `backtest/calibrate.py` | PositionPnL list | From `pnl.py` |
| `backtest/oracle_comparison.py` | RAW_POSITIONS (via `positions_from_raw_data`) | Converts tuples to PositionExit objects |
| `backtest/synthetic_exits.py` | RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP | Via `build_from_raw_positions` |
| `backtest/mechanism_sweep.py` | PositionExit list, DailyPoolState list | From oracle_comparison + daily |
| `backtest/plotting.py` | BacktestResult | From pipeline output |

**Data origin chain**: All backtest data traces back to Dune queries frozen in `econometrics/data.py`. No external data fetches occur at runtime.

### Key parameter: `POOL_DAILY_FEE = 50_000.0` (set by notebooks/tests, not in data.py)

---

## 5. Notebook Data Dependencies

All notebooks use `sys.path.insert(0, "..")` to import from `research/` modules.

### 5.1 `notebooks/cross-pool-concentration-severity.ipynb`
- **Imports**: `cross_pool.data.SELECTED_POOLS`, `cross_pool.data.POOL_CONCENTRATIONS`
- **Imports**: `cross_pool.analysis.{spearman_rank, summary_table, architecture_decision, scatter_at_vs_tvl, scatter_delta_vs_tvl}`
- **Data source**: All hardcoded in `cross_pool/data.py`
- **Purpose**: Architecture decision: should insurance be per-hook or per-CFMM pool?

### 5.2 `notebooks/duration_results.ipynb`
- **Imports**: `econometrics.data.{DAILY_AT_MAP, IL_MAP, RAW_POSITIONS}`
- **Imports**: `econometrics.ingest.build_lagged_positions`
- **Imports**: `econometrics.duration.{duration_model_robust, economic_magnitude, nested_models, quartile_analysis, sensitivity_sweep}`
- **Data source**: Hardcoded in `econometrics/data.py`
- **Purpose**: Duration model results, dose-response quartile analysis

### 5.3 `notebooks/eth-usdc-backtest.ipynb`
- **Imports**: `econometrics.data.{DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP, RAW_POSITIONS}`
- **Imports**: `backtest.daily.build_daily_states`, `backtest.sweep.{run_single_backtest, run_gamma_sweep}`, `backtest.calibrate.*`, `backtest.plotting.*`
- **Data source**: Hardcoded in `econometrics/data.py`
- **Purpose**: Full insurance backtest with gamma sweep, money plots, reserve trajectory

### 5.4 `notebooks/eth-usdc-insurance-demand-identification.ipynb`
- **Imports**: `econometrics.data.{DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP, RAW_POSITIONS}`
- **Imports**: `econometrics.ingest.build_exit_panel_deviation`
- **Imports**: `econometrics.hazard.{logit_mle_quadratic, exit_quartile_analysis}`
- **Data source**: Hardcoded in `econometrics/data.py`
- **Purpose**: Exit hazard model with quadratic treatment, inverted-U identification, turning point (Delta*)

### 5.5 `notebooks/oracle-accumulation-comparison.ipynb`
- **Imports**: `econometrics.data.{RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP}`
- **Imports**: `backtest.oracle_comparison.*`, `backtest.mechanism_sweep.*`, `backtest.daily.*`, `backtest.payoff.*`
- **Data source**: Hardcoded in `econometrics/data.py`
- **Purpose**: Compare cumulative vs daily-snapshot oracle, mechanism sweep (epoch/decay/window)

---

## 6. Oracle Scripts

### 6.1 `research/data/scripts/fci_oracle.py` (15K, executable)
- **Purpose**: Replays V4 FCI state machine against raw events to produce test fixtures
- **Reads**: `data/raw/fci_weth_usdc_v4_events.json` (line 360-368)
- **Writes**: `data/fixtures/fci_weth_usdc_v4.json` (line 391-392)
- **Behavior**: Pure computation, no network calls. Implements V4 position key derivation (keccak256 of sender+tickLower+tickUpper+salt), tick range intersection for swap counting, Q128 fixed-point FCI math.
- **Snapshot blocks**: Hardcoded at line 298: `[23659523, 23662024, 23665656, 23667514]`

### 6.2 `research/data/scripts/fci_epoch_oracle.py` (3.2K)
- **Purpose**: Epoch-reset FCI oracle for Solidity differential testing
- **Reads**: Nothing (FFI entry point)
- **Behavior**: Called via FFI from Solidity fuzz tests. Takes CLI args `(x_squared_q128, block_lifetime, epoch_length, timestamp)`, returns delta_plus.
- **Usage**: `python fci_epoch_oracle.py <x_squared_q128> <block_lifetime> <epoch_length> <timestamp>`

### 6.3 `research/scripts/hhi_oracle.py` (3.5K approx)
- **Purpose**: Off-chain HHI oracle for Foundry FFI fuzz tests
- **Reads**: Nothing (FFI entry point)
- **Behavior**: Accepts hex-encoded ABI `(uint256[] liquidities, uint256[] blockLifetimes)`, returns hex-encoded `(hhi, indexA, thetaSum, removedPosCount, atNull, deltaPlus)`. Uses `eth_abi` for encoding/decoding.
- **Called from**: `test/fee-concentration-index/fuzz/FeeConcentrationIndexFull.fuzz.t.sol:96`

### 6.4 `research/scripts/fci_v3_oracle.py` (11K approx)
- **Purpose**: V3 FCI oracle -- replays V3 events (Swap/Mint/Burn/Collect) through FCI state machine
- **Reads**: `data/raw/fci_v3_weth_usdc_events.json` (line 369) -- **NOTE: this file does not currently exist**
- **Writes**: `data/fixtures/fci_v3_weth_usdc.json` (line 370) -- **NOTE: this file does not currently exist**
- **Behavior**: V3-specific position key (no salt), tracks Collect fees per position, processes Burn events for FCI terms

### 6.5 `research/scripts/compare_fci.py` (5K approx)
- **Purpose**: On-chain vs off-chain FCI convergence checker
- **Reads**: Fixture file (configurable via `FIXTURES_PATH` env var, default `research/data/fixtures/fci_v3_weth_usdc.json`)
- **Behavior**: **Live RPC calls** to Sepolia via `SEPOLIA_RPC_URL` env var. Calls `getIndex(PoolKey)` on the ReactiveHookAdapter and compares against fixture snapshots. Uses `httpx` for JSON-RPC.

---

## 7. Test Data Dependencies

### 7.1 Tests Using Hardcoded Production Data (`econometrics/data.py`)

| Test File | Data Variables Used | Lines |
|-----------|-------------------|-------|
| `tests/econometrics/test_data.py` | RAW_POSITIONS, DAILY_AT_MAP, IL_MAP | 4, 8, 13, 18, 24, 29 |
| `tests/econometrics/test_duration.py` | RAW_POSITIONS, DAILY_AT_MAP, IL_MAP (via import) | 82-84 |
| `tests/econometrics/test_hazard.py` | RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP | 91-97, 108-109 |
| `tests/backtest/test_synthetic_exits.py` | RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP | 13, 56-60 |
| `tests/backtest/test_mechanism_sweep.py` | RAW_POSITIONS, DAILY_AT_MAP, DAILY_AT_NULL_MAP, IL_MAP | 205-224 |

### 7.2 Tests Using Local Synthetic Data

| Test File | Data Source |
|-----------|------------|
| `tests/econometrics/test_ingest.py` | Inline synthetic DuneRow dicts and mock data |
| `tests/econometrics/test_estimate.py` | JAX random data generation |
| `tests/econometrics/test_types.py` | Inline construction of frozen dataclasses |
| `tests/econometrics/cross_pool/test_analysis.py` | Inline numeric arrays |
| `tests/econometrics/cross_pool/test_subgraph.py` | Inline PoolInfo objects |
| `tests/backtest/test_types.py` | Inline dataclass construction |
| `tests/backtest/test_daily.py` | Local DAILY_AT_MAP/RAW_POSITIONS dicts (5-day synthetic, lines 9-40) |
| `tests/backtest/test_payoff.py` | Local SIMPLE_STATES/SIMPLE_POSITIONS (lines 15-40) |
| `tests/backtest/test_pnl.py` | Inline DailyPoolState/ReserveState objects |
| `tests/backtest/test_calibrate.py` | Inline PositionPnL objects |
| `tests/backtest/test_oracle_comparison.py` | Inline PositionExit objects |

### 7.3 Solidity Test Data Dependencies

| Test File | Data Source | Line |
|-----------|------------|------|
| `test/fee-concentration-index/differential/FeeConcentrationIndexPythonFFI.diff.fork.t.sol` | `research/data/fixtures/fci_weth_usdc_v4.json` via `vm.readFile` | 87 |
| `test/fee-concentration-index/fuzz/FeeConcentrationIndexFull.fuzz.t.sol` | `research/scripts/hhi_oracle.py` via FFI | 96 |

`foundry.toml` line 10 grants read access: `{ access = "read", path = "research/data/fixtures" }`

---

## 8. Data Source Type Summary

| Source Type | Files | Description |
|-------------|-------|-------------|
| **Hardcoded Python dicts** | `econometrics/data.py`, `econometrics/cross_pool/data.py`, `econometrics/per_position_data.py` | Frozen Dune query results embedded directly in source. This is the single source of truth for all analysis. |
| **Static JSON files** | `data/raw/*.json`, `data/fixtures/*.json`, `data/econometrics/*.json` | Event streams (from Dune), computed fixtures (from oracle scripts), and serialized model results. |
| **Dune SQL queries** | `data/queries/dune/*.sql`, `data/queries/*.sql` | 7 SQL files for reproducibility. Total reproduction cost: ~5 credits. Results already frozen. |
| **GraphQL queries** | `data/queries/subgraph/*.graphql` | 1 query for V3 pool discovery. Results frozen in `cross_pool/data.py`. |
| **Live RPC calls** | `scripts/compare_fci.py` | Only script that makes live network calls (Sepolia). Requires env vars. |
| **FFI oracles** | `scripts/hhi_oracle.py`, `data/scripts/fci_epoch_oracle.py` | Called by Foundry tests via CLI, no network calls. |
| **Computed/derived** | `data/scripts/fci_oracle.py`, `scripts/fci_v3_oracle.py` | Transform raw JSON events into fixture JSON with expected values. |

---

## 9. Findings and Recommendations

### 9.1 Missing Files
- `data/raw/fci_v3_weth_usdc_events.json` -- referenced by `scripts/fci_v3_oracle.py:369` but does not exist. The V3 oracle script will fail if run.
- `data/fixtures/fci_v3_weth_usdc.json` -- would be generated by the V3 oracle. Referenced by `scripts/compare_fci.py:142` as default fixture path.

### 9.2 Data Freeze Date
All Dune query results are frozen as of **2026-03-05** (documented in `data/queries/README.md:38`). Re-execution will produce different results due to new on-chain activity.

### 9.3 Pool Mismatch
The econometrics data uses **ETH/USDC 30bps** pool (`0x8ad5...`, fee=3000) for the duration/hazard models, while the FCI oracle/fixture data uses **WETH/USDC V4 5bps** pool (`0x4f88...`, fee=500). The cross-pool analysis covers 10 pools spanning both. This is intentional -- different pools serve different analytical purposes.

### 9.4 Unused Query
`data/queries/dune/fci_v3_weth_usdc_events.sql` is parameterized (`{{block_start}}, {{block_end}}`) and was likely used to populate V3 event data for the reactive integration, but its output file is missing from the repo.

### 9.5 Archive
`research/_archive/` contains two deprecated files (`sweep.py`, `reserve.py`) that appear to be predecessors of the current `backtest/mechanism_sweep.py` and `backtest/` modules.
