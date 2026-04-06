// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Per-NoteId mutable state, set on first mint and updated on mint/burn/claim.
/// @dev The NoteId itself encodes all parameters (range, epoch, flags, etc.).
///      NoteSnapshot stores only the runtime state that can't be known at construction.
///      Initialization check: totalLiquidity > 0 means the snapshot has been set.
struct NoteSnapshot {
    uint256 entryGrowthInside;  // growthInside at first mint for this NoteId
    uint256 entryGlobalGrowth;  // globalGrowth at first mint for this NoteId
    uint128 totalLiquidity;     // Sum of all minted liquidity units (decremented on burn)
}
