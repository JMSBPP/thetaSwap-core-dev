"""Pure functions: Dune MCP JSON rows → typed domain objects."""
from __future__ import annotations

from dataclasses import replace
from typing import Sequence

from econometrics.types import DailyPanelRow, DuneRow


def ingest_daily_panel(rows: Sequence[DuneRow]) -> list[DailyPanelRow]:
    """Convert Dune Q2 result rows to DailyPanelRow list.

    Args:
        rows: List of dicts from Dune getExecutionResults.

    Returns:
        Typed panel rows with jit_count_lag1 defaulted to 0
        (populated later by merge_jit_instrument).
    """
    return [
        DailyPanelRow(
            day=str(r["day"]),
            a_t=float(r["a_t"]),
            passive_exit_count=int(r["passive_exit_count"]),
            total_positions=int(r["total_positions"]),
            jit_count=int(r["jit_count"]),
            swap_count=int(r["swap_count"]),
            jit_count_lag1=0,
        )
        for r in rows
    ]


def merge_jit_instrument(
    panel: Sequence[DailyPanelRow],
    q3_rows: Sequence[DuneRow],
) -> list[DailyPanelRow]:
    """Merge Q3 lagged JIT instrument into panel rows.

    Args:
        panel: Panel rows from ingest_daily_panel.
        q3_rows: Dune Q3 result with day, jit_count, jit_count_lag1.

    Returns:
        New panel rows with jit_count_lag1 populated.
    """
    lag_map: dict[str, int] = {
        str(r["day"]): int(r["jit_count_lag1"]) for r in q3_rows
    }
    return [
        replace(row, jit_count_lag1=lag_map.get(row.day, 0))
        for row in panel
    ]
