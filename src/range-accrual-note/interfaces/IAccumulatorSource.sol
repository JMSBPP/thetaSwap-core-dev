// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange} from "typed-uniswap-v4/types/TickRangeMod.sol";

/// @title IAccumulatorSource
/// @notice Protocol-agnostic interface for reading fee/reward growth accumulators.
/// @dev Return values use LeftRight packing convention:
///   left 128 bits (int128) = token0 growth per unit liquidity
///   right 128 bits (int128) = token1 growth per unit liquidity
/// For single-token accumulators (e.g., Angstrom bid_in_asset0), right slot is zero.
///
/// Implementations MUST handle all three tick-position cases internally:
///   current_tick < tickLower:  growthOutside[lower] - growthOutside[upper]
///   current_tick in [lower, upper): globalGrowth - growthOutside[lower] - growthOutside[upper]
///   current_tick >= tickUpper: growthOutside[upper] - growthOutside[lower]
///
/// TickRange must use packed encoding (fromTicksPacked) so ticks are recoverable.
interface IAccumulatorSource {
    /// @notice Accumulated growth inside a tick range, LeftRight-packed.
    function growthInside(PoolId poolId, TickRange range)
        external view returns (int256);

    /// @notice Global cumulative growth, LeftRight-packed.
    function globalGrowth(PoolId poolId) external view returns (int256);

    /// @notice Epoch number for a given block number.
    /// @dev Uses uint64 to match Angstrom's block number convention.
    function epochOf(uint64 blockNumber) external view returns (uint40);

    /// @notice Epoch length in blocks.
    function epochLength() external view returns (uint64);
}
