# Econometrics Comparison Report: Original Q4v2 vs NFT Query Positions

**Date**: 2026-03-17
**Branch**: 008-uniswap-v3-reactive-integration
**Script**: `/home/jmsbpp/apps/ThetaSwap/thetaSwap-core-dev/tmp/compare_positions_econometrics.py`

---

## Executive Summary

This report compares the econometric model outputs using two position datasets for the ETH/USDC 30bps pool (0x8ad5...):

1. **Original (Q4v2)**: 600 positions hardcoded in `research/econometrics/data.py`, extracted via Dune Q4v2 with pagination. Blocklife values in the range ~4-260K blocks.
2. **NFT Query**: 618 positions from the Dune NFT query execution. Blocklife values in the range ~3-4.27M blocks (much larger scale).

**Key finding**: The two datasets represent fundamentally different blocklife scales -- the NFT query returns raw block counts that are roughly 4x larger on average than the Q4v2 values. Despite this scale difference, both datasets produce the same directional conclusions for the primary coefficient of interest (beta_a_t), confirming the robustness of the fee concentration effect.

---

## Raw Output

```
==========================================================================================
ECONOMETRICS COMPARISON: Original RAW_POSITIONS vs NFT Query Positions
==========================================================================================

--- Dataset Overview ---
  Original RAW_POSITIONS total:  600
  NFT query positions total:     618
  Original after blocklife>1:    600
  NFT after blocklife>1:         618
  Original unique burn dates:    41
  NFT unique burn dates:         41

  Blocklife stats (after filter):
    Metric                      Original             NFT       Diff
    ------------------------------------------------------------
    Mean                         36499.9        159817.9    +337.9%
    Median                       16272.0         53679.5    +229.9%
    Stdev                        49037.8        350089.2    +613.9%
    Min                              4.0             3.0     -25.0%
    Max                         260991.0       4265206.0   +1534.2%

==========================================================================================
1. DURATION MODEL: log(blocklife) = b0 + b1*A_T + b2*IL
   Lagged treatment (lag_days=5, measure=max)
==========================================================================================

  Positions included in lagged model:
    Original: 191
    NFT:      312

  Coefficient                   Original          NFT     % Diff
  -----------------------------------------------------------
  beta_intercept               10.875526    11.582885      +6.5%
  beta_a_t                      5.336476     6.292229     +17.9%
  beta_il                      -0.073482   -14.685473  -19885.2%
  robust_se_a_t                 0.327697     0.579869     +77.0%
  robust_se_il                  5.948705    12.023184    +102.1%
  robust_p_a_t                  0.000000     0.000000        inf
  robust_p_il                   0.990144     0.221923     -77.6%
  R-squared                     0.584128     0.265604     -54.5%
  n_obs                              191          312     +63.4%
  mean_blocklife            91917.632812 269602.062500    +193.3%
  mean_bl_hours               306.392109   898.673542    +193.3%

==========================================================================================
2. HAZARD MODEL (DEVIATION): P(exit) = sigma(b0 + b1*(A_T - A_T_null) + b2*IL + b3*log(age))
   Day-clustered sandwich SEs
==========================================================================================

  Panel rows:
    Original: 3365
    NFT:      6054

  Coefficient                   Original          NFT     % Diff
  -----------------------------------------------------------
  beta_intercept               -1.071803    -1.450074     -35.3%
  beta_a_t (deviation)         -5.436818    -4.920415      +9.5%
  beta_il                       6.659092    20.463263    +207.3%
  beta_log_age                 -0.415727    -0.388320      +6.6%
  se_a_t (MLE)                  2.071713     2.161080      +4.3%
  cluster_se_a_t                3.389458     3.828130     +12.9%
  p_value_a_t (MLE)             0.008682     0.022796    +162.6%
  cluster_p_a_t                 0.108706     0.198677     +82.8%
  pseudo_R2                     0.347672     0.553916     +59.3%
  log_likelihood            -1521.515869 -1871.910156     -23.0%
  AIC                        3051.031738  3751.820312     +23.0%
  mean_exit_prob                0.177415     0.099438     -44.0%
  n_obs                             3365         6054     +79.9%
  n_exits                            597          602      +0.8%
  n_clusters                          40           40      +0.0%

==========================================================================================
3. SIGN AND SIGNIFICANCE SUMMARY
==========================================================================================

  Duration model beta_a_t:
    Original: +5.3365 (p=0)
    NFT:      +6.2922 (p=1.97e-27)
    Sign match: YES

  Hazard model beta_a_t (deviation):
    Original: -5.4368 (cluster p=0.1087)
    NFT:      -4.9204 (cluster p=0.1987)
    Sign match: YES

  Duration model beta_il:
    Original: -0.0735 (p=0.9901)
    NFT:      -14.6855 (p=0.2219)

==========================================================================================
COMPARISON COMPLETE
==========================================================================================
```

---

## Detailed Analysis

### 1. Dataset Differences

| Metric | Original (Q4v2) | NFT Query | Ratio |
|--------|----------------|-----------|-------|
| Total positions | 600 | 618 | 1.03x |
| After blocklife>1 filter | 600 | 618 | 1.03x |
| Unique burn dates | 41 | 41 | 1.0x |
| Mean blocklife | 36,500 | 159,818 | 4.4x |
| Median blocklife | 16,272 | 53,680 | 3.3x |
| Max blocklife | 260,991 | 4,265,206 | 16.3x |
| Lagged model positions (lag=5) | 191 | 312 | 1.63x |
| Hazard panel rows | 3,365 | 6,054 | 1.80x |

The NFT query blocklife values are ~3-4x larger than the original. This suggests the NFT query measures blocklife in a different unit or includes positions from a broader population (possibly the full NFT set vs a filtered subset). The 18 additional positions (618 vs 600) and the dramatically different blocklife scale confirm these are not the same extraction.

The NFT query produces 312 positions in the lagged duration model vs 191 for the original. This is because NFT positions with larger blocklives have longer implied mint-to-burn windows, creating more overlap with the DAILY_AT_MAP observation window (Dec 5 - Jan 14), so more positions survive the lagged treatment filter.

### 2. Duration Model Comparison

| Coefficient | Original | NFT | Same Sign | Both Significant |
|-------------|----------|-----|-----------|-----------------|
| beta_a_t | +5.337 | +6.292 | YES | YES (both p~0) |
| beta_il | -0.073 | -14.685 | YES | NO (both insig) |
| R-squared | 0.584 | 0.266 | -- | -- |

**beta_a_t (primary coefficient)**: Both datasets show a strong, highly significant positive effect of fee concentration (A_T) on log(blocklife). The NFT estimate is +17.9% larger in magnitude. Both are significant at any conventional level.

**Interpretation**: Higher lagged max A_T is associated with longer position lifetimes (positive beta). This is consistent across both datasets. The positive sign means concentrated pools retain LPs longer -- this may seem counterintuitive but reflects that high-A_T days correspond to pools with dominant long-lived positions (survivorship effect).

**R-squared drop**: The original model explains 58% of blocklife variation vs 27% for the NFT data. The NFT data has much higher blocklife variance (stdev 350K vs 49K), introducing noise that the A_T + IL regressors cannot capture.

**beta_il**: Statistically insignificant in both datasets (p=0.99 original, p=0.22 NFT), confirming IL proxy has no reliable effect on duration.

### 3. Hazard Model Comparison

| Coefficient | Original | NFT | Same Sign | Significant (cluster) |
|-------------|----------|-----|-----------|----------------------|
| beta_a_t (deviation) | -5.437 | -4.920 | YES | NO (p=0.11 / p=0.20) |
| beta_il | +6.659 | +20.463 | YES | -- |
| beta_log_age | -0.416 | -0.388 | YES | -- |
| pseudo_R2 | 0.348 | 0.554 | -- | -- |

**beta_a_t (deviation from null)**: Both datasets show a negative effect -- higher fee concentration deviation *reduces* exit probability. Same sign, 9.5% difference in magnitude. Neither is significant at the 5% level with day-clustered SEs (p=0.11 original, p=0.20 NFT), though the original is marginally significant at 10%.

**mean_exit_prob**: Drops from 17.7% to 9.9% for the NFT data. With longer blocklives, positions span more observation days in the panel, diluting the exit rate (same ~600 exits spread across 6054 vs 3365 rows).

**pseudo_R2**: The NFT model has *higher* pseudo R-squared (0.554 vs 0.348), suggesting log(age) is more predictive for the longer-lived NFT positions.

### 4. Robustness Assessment

The core research conclusions are robust across both datasets:

1. **Fee concentration (A_T) effect on duration**: Positive and highly significant in both. The magnitude is stable (+17.9% difference).

2. **Fee concentration deviation effect on exits**: Negative in both (higher concentration reduces exits). Not statistically significant with day-clustered SEs in either dataset -- this was already the case with the original data.

3. **IL proxy**: Insignificant in both duration models. Larger magnitude in NFT hazard model but IL is a secondary control, not the parameter of interest.

4. **Sign consistency**: All coefficients maintain the same sign across datasets.

### 5. Key Differences Explained

The primary source of divergence is the **blocklife scale difference** (~4x). This propagates through:

- **`approximate_mint_date()`**: Larger blocklives push mint dates further back, increasing the window for lagged A_T computation. More positions survive the lag filter (312 vs 191).
- **Panel expansion**: Longer positions contribute more position-day rows to the hazard panel (6054 vs 3365), but with roughly the same exit count (602 vs 597).
- **R-squared**: The duration model R-squared drops because the expanded blocklife range introduces variance that A_T alone cannot explain.

---

## Conclusions

1. The NFT query and original Q4v2 data appear to come from the same pool and date range but with different blocklife measurement scales.
2. The direction and approximate magnitude of the primary coefficient (beta_a_t) are consistent across both datasets.
3. Neither dataset produces a statistically significant hazard model beta_a_t with day-clustered SEs -- this is a known limitation of the 41-day observation window.
4. The original Q4v2 data (600 positions, ~36K mean blocklife) remains the better-characterized dataset for the published econometric results.
