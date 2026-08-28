// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange} from "typed-uniswap-v4/types/TickRangeMod.sol";

/// @title IAccumulatorSource
/// @notice Protocol-agnostic interface for reading fee/reward growth accumulators.
/// @dev Returns uint256 matching the native accumulator type used by Uniswap V3/V4
/// and Angstrom's GrowthOutsideUpdater. Accumulators are monotonically increasing
/// unsigned values that use unchecked wrapping arithmetic for deltas.
///
/// For protocols with two-token fee growth (V3/V4), adapters should return token0
/// growth only. Token1 growth can be exposed via a separate adapter or extension.
///
/// Implementations MUST handle all three tick-position cases internally:
///   current_tick < tickLower:  growthOutside[lower] - growthOutside[upper]
///   current_tick in [lower, upper): globalGrowth - growthOutside[lower] - growthOutside[upper]
///   current_tick >= tickUpper: growthOutside[upper] - growthOutside[lower]
///
/// TickRange must use packed encoding (fromTicksPacked) so ticks are recoverable.
interface IAccumulatorSource {
    /// @notice Accumulated growth inside a tick range.
    function growthInside(PoolId poolId, TickRange range)
        external view returns (uint256);

    /// @notice Global cumulative growth.
    function globalGrowth(PoolId poolId) external view returns (uint256);

    /// @notice Epoch number for a given block number.
    /// @dev Uses uint64 to match Angstrom's block number convention.
    function epochOf(uint64 blockNumber) external view returns (uint40);

    /// @notice Epoch length in blocks.
    function epochLength() external view returns (uint64);
}
