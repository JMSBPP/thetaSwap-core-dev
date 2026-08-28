// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Per-NoteId mutable state, set on first mint and updated on mint/burn/claim.
/// @dev The NoteId itself encodes all parameters (range, epoch, flags, etc.).
///      NoteSnapshot stores only the runtime state that can't be known at construction.
///      Initialization check: totalLiquidity > 0 means the snapshot has been set.
///
///      Settlement uses the Pap (2022) ratio: n/N = growthInside_delta / globalGrowth_delta
///        numerator:   growthInside(now) - entryGrowthInside   (range-specific accrual)
///        denominator: globalGrowth(now) - entryGlobalGrowth   (total pool accrual)
///      This ratio ∈ [0, 1] represents the fraction of epoch time the range was active.
///      The short side bets on range exit (ratio → 0), long bets on stability (ratio → 1).
struct NoteSnapshot {
    uint256 entryGrowthInside;  // growthInside at first mint (numerator baseline)
    uint256 entryGlobalGrowth;  // globalGrowth at first mint (denominator baseline)
    uint128 totalLiquidity;     // sum of all minted liquidity units (decremented on burn)
}
