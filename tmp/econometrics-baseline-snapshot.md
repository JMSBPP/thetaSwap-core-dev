# Econometrics Baseline Snapshot

Generated: 2026-03-17
Branch: 008-uniswap-v3-reactive-integration
Commit: 73976c8

---

## 1. Test Suite Results

**139 passed, 0 failed, 0 errors** (15.06s)

Python 3.14.3, pytest 9.0.2

### Breakdown by module

| Module | Tests | Status |
|--------|-------|--------|
| backtest/test_calibrate | 5 | All passed |
| backtest/test_daily | 6 | All passed |
| backtest/test_mechanism_sweep | 22 | All passed |
| backtest/test_oracle_comparison | 17 | All passed |
| backtest/test_payoff | 11 | All passed |
| backtest/test_pnl | 4 | All passed |
| backtest/test_synthetic_exits | 5 | All passed |
| backtest/test_types | 8 | All passed |
| econometrics/cross_pool/test_analysis | 5 | All passed |
| econometrics/cross_pool/test_subgraph | 4 | All passed |
| econometrics/test_data | 5 | All passed |
| econometrics/test_duration | 6 | All passed |
| econometrics/test_estimate | 5 | All passed |
| econometrics/test_hazard | 8 | All passed |
| econometrics/test_ingest | 18 | All passed |
| econometrics/test_types | 7 | All passed |

---

## 2. Duration Model

**Source**: `research/data/econometrics/duration_result.json`
**Model**: `log(blocklife) ~ max_A_T + IL` with HC1 robust standard errors
**n = 191, R-squared = 0.5841**

| Coefficient | Estimate | OLS SE | Robust (HC1) SE | p-value (robust) |
|-------------|----------|--------|------------------|-------------------|
| Intercept | 10.8755 | -- | -- | -- |
| beta_a_t (max_A_T) | 5.3365 | 0.3331 | 0.3277 | 0.000000 |
| beta_il (IL) | -0.0735 | 6.2830 | 5.9487 | 0.990144 |

**Key finding**: A 0.10 increase in max A_T corresponds to +70.5% position life (~216.0 hours).
IL coefficient is statistically insignificant (p = 0.99).

**Summary statistics**:
- Mean blocklife: 91,918 blocks (306.4 hours)
- Positions (lag=5): 191

---

## 3. Estimation Result (Contemporaneous Logit)

**Source**: `research/data/econometrics/estimation_result.json`
**n = 91, Pseudo R-squared = 0.3585**

| Parameter | Estimate | SE | p-value |
|-----------|----------|----|---------|
| beta_concentration | -0.1748 | 0.0341 | 2.96e-07 |
| beta_swap | 0.4834 | -- | -- |
| beta_jit_lag | -2.2200 | -- | -- |

- WTP mean: 5.494e-07
- Log-likelihood: -41.344
- AIC: 90.688

---

## 4. Lagged Estimation Results (All Specifications)

**Source**: `research/data/econometrics/estimation_result_lagged.json`

### 4a. Specification Comparison

| Specification | beta_conc | SE | p-value | Pseudo R2 | WTP mean | AIC |
|--------------|-----------|-----|---------|-----------|----------|------|
| Contemporaneous A_T | -0.1748 | 0.0341 | 2.96e-07 | 0.3585 | 5.49e-07 | 90.69 |
| Lag-1 A_T (yesterday) | -0.4539 | 0.0311 | 0.0000 | 0.3724 | 5.23e-06 | 88.51 |
| 3-day MA A_T | -0.6461 | 0.0386 | 0.0000 | 0.3799 | 1.76e-05 | 87.48 |
| 7-day MA A_T | -0.7500 | 0.0367 | 0.0000 | 0.3933 | 7.86e-06 | 85.82 |
| Cumulative Max A_T | +0.5405 | 0.0346 | 0.0000 | 0.3737 | 0.0000 | 88.31 |

**Best AIC**: 7-day MA A_T (85.82), also highest Pseudo R2 (0.3933).
**Concentration always significant** (p < 1e-6 for all specs).
**Cumulative Max** has a positive sign (opposite direction), suggesting it captures a different phenomenon.

### 4b. Control Variables Across Specs

| Specification | beta_swap | beta_jit_lag |
|--------------|-----------|--------------|
| Contemporaneous | 0.4834 | -2.2200 |
| Lag-1 | 0.3987 | -2.2901 |
| 3-day MA | 0.1557 | -2.3212 |
| 7-day MA | 0.1109 | -2.1330 |
| Cumulative Max | 0.6173 | -2.0197 |

JIT lag coefficient is consistently strongly negative across all specs (-2.0 to -2.3).

### 4c. Predictive Specification (Next-Day Exit)

| Parameter | Estimate | SE | p-value |
|-----------|----------|----|---------|
| beta_concentration | -0.2663 | 0.0286 | 1.39e-20 |
| beta_swap | 0.1054 | -- | -- |
| beta_jit_lag | -0.7259 | -- | -- |

- n = 90, Pseudo R2 = 0.0964
- Log-likelihood: -56.355
- AIC: 120.710
- WTP mean: 0.0

Lower R2 as expected for predictive (out-of-sample-like) specification, but concentration
coefficient remains highly significant (p = 1.39e-20).

---

## 5. Errors Encountered

None. All commands completed successfully.

---

## 6. File Locations

- Duration result: `research/data/econometrics/duration_result.json`
- Estimation result: `research/data/econometrics/estimation_result.json`
- Lagged estimation result: `research/data/econometrics/estimation_result_lagged.json`
- Duration runner: `research/econometrics/run_duration.py`
- Test suite: `research/tests/`
