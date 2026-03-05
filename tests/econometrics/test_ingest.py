"""Tests for Dune MCP JSON → JAX array ingestion."""
from __future__ import annotations

import jax.numpy as jnp
from econometrics.ingest import (
    approximate_mint_date,
    build_lagged_positions,
    compute_lagged_treatment,
    ingest_daily_panel,
    merge_jit_instrument,
)
from econometrics.types import DailyPanelRow


def test_ingest_daily_panel_basic() -> None:
    """Convert Dune Q2 rows to DailyPanelRow list."""
    rows = [
        {"day": "2026-01-01", "a_t": 0.35, "passive_exit_count": 10,
         "total_positions": 25, "jit_count": 5, "swap_count": 100},
        {"day": "2026-01-02", "a_t": 0.42, "passive_exit_count": 8,
         "total_positions": 20, "jit_count": 3, "swap_count": 80},
    ]
    result = ingest_daily_panel(rows)
    assert len(result) == 2
    assert isinstance(result[0], DailyPanelRow)
    assert result[0].a_t == 0.35
    assert result[1].swap_count == 80
    assert result[0].jit_count_lag1 == 0


def test_merge_jit_instrument() -> None:
    """Merge Q3 lagged JIT counts into panel rows."""
    panel = [
        DailyPanelRow("2026-01-01", 0.3, 10, 25, 5, 100, 0),
        DailyPanelRow("2026-01-02", 0.4, 8, 20, 3, 80, 0),
    ]
    q3_rows = [
        {"day": "2026-01-01", "jit_count": 5, "jit_count_lag1": 0},
        {"day": "2026-01-02", "jit_count": 3, "jit_count_lag1": 5},
    ]
    merged = merge_jit_instrument(panel, q3_rows)
    assert merged[0].jit_count_lag1 == 0
    assert merged[1].jit_count_lag1 == 5


def test_ingest_empty_rows() -> None:
    """Empty input returns empty list."""
    assert ingest_daily_panel([]) == []


def test_merge_preserves_other_fields() -> None:
    """Merge only touches jit_count_lag1, leaves rest intact."""
    panel = [DailyPanelRow("2026-01-01", 0.55, 12, 30, 7, 150, 0)]
    q3_rows = [{"day": "2026-01-01", "jit_count": 7, "jit_count_lag1": 4}]
    merged = merge_jit_instrument(panel, q3_rows)
    assert merged[0].a_t == 0.55
    assert merged[0].passive_exit_count == 12
    assert merged[0].jit_count_lag1 == 4


# ── Lagged treatment tests ────────────────────────────────────────────

SAMPLE_DAILY_AT: dict[str, float] = {
    "2025-12-20": 0.10,
    "2025-12-21": 0.15,
    "2025-12-22": 0.20,
    "2025-12-23": 0.12,
    "2025-12-24": 0.18,
    "2025-12-25": 0.25,
    "2025-12-26": 0.11,
    "2025-12-27": 0.14,
}

SAMPLE_IL: dict[str, float] = {
    "2025-12-27": 0.01,
}

BLOCKS_PER_DAY = 7200


def test_approximate_mint_date() -> None:
    # 7 days * 7200 blocks/day = 50400 blocks
    result = approximate_mint_date("2025-12-27", 50400)
    assert result == "2025-12-20"


def test_approximate_mint_date_short_position() -> None:
    # 1 day = 7200 blocks
    result = approximate_mint_date("2025-12-27", 7200)
    assert result == "2025-12-26"


def test_compute_lagged_treatment_lag_0() -> None:
    # mint=Dec 20, burn=Dec 27, lag=0 -> range [Dec 20, Dec 27]
    max_at, mean_at, median_at = compute_lagged_treatment(
        SAMPLE_DAILY_AT, "2025-12-20", "2025-12-27", lag_days=0,
    )
    assert max_at == 0.25  # Dec 25
    assert abs(mean_at - sum(SAMPLE_DAILY_AT.values()) / 8) < 1e-6


def test_compute_lagged_treatment_lag_2() -> None:
    # mint=Dec 20, burn=Dec 27, lag=2 -> range [Dec 20, Dec 25]
    max_at, mean_at, median_at = compute_lagged_treatment(
        SAMPLE_DAILY_AT, "2025-12-20", "2025-12-27", lag_days=2,
    )
    assert max_at == 0.25  # Dec 25 is still included (burn-2 = Dec 25)
    # range is Dec 20-25 = 6 values: 0.10, 0.15, 0.20, 0.12, 0.18, 0.25
    assert abs(mean_at - (0.10 + 0.15 + 0.20 + 0.12 + 0.18 + 0.25) / 6) < 1e-6


def test_compute_lagged_treatment_lag_5() -> None:
    # mint=Dec 20, burn=Dec 27, lag=5 -> range [Dec 20, Dec 22]
    max_at, mean_at, median_at = compute_lagged_treatment(
        SAMPLE_DAILY_AT, "2025-12-20", "2025-12-27", lag_days=5,
    )
    assert max_at == 0.20  # Dec 22
    # range is Dec 20-22 = 3 values: 0.10, 0.15, 0.20
    assert abs(median_at - 0.15) < 1e-6


def test_compute_lagged_treatment_empty_range_returns_none() -> None:
    # lag exceeds position lifetime -> no data
    result = compute_lagged_treatment(
        SAMPLE_DAILY_AT, "2025-12-26", "2025-12-27", lag_days=5,
    )
    assert result is None


def test_build_lagged_positions() -> None:
    raw = [
        ("2025-12-27", 50400, 0.14),  # mint ~Dec 20, good coverage
    ]
    positions = build_lagged_positions(raw, SAMPLE_DAILY_AT, SAMPLE_IL, lag_days=2)
    assert len(positions) == 1
    assert positions[0].mint_date == "2025-12-20"
    assert positions[0].il_proxy == 0.01


def test_build_lagged_positions_excludes_short_coverage() -> None:
    raw = [
        ("2025-12-21", 7200, 0.15),  # mint ~Dec 20, only 1 day before burn-2 = nothing
    ]
    positions = build_lagged_positions(raw, SAMPLE_DAILY_AT, SAMPLE_IL, lag_days=2)
    # mint=Dec 20, burn-2=Dec 19 -> range [Dec 20, Dec 19] -> empty -> excluded
    assert len(positions) == 0
