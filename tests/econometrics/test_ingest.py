"""Tests for Dune MCP JSON → JAX array ingestion."""
from __future__ import annotations

import jax.numpy as jnp
from econometrics.ingest import ingest_daily_panel, merge_jit_instrument
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
