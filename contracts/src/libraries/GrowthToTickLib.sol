// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {FullMath} from "v4-core/src/libraries/FullMath.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {FixedPoint128} from "v4-core/src/libraries/FixedPoint128.sol";

/// @notice Stages 1-3 of the growth-to-tick pipeline: Q128.128 ratio → Q64.64 sqrt → Q64.96 sqrtPriceX96.
/// @dev Extracted so rate providers (RAY/WAD consumers) can skip the TickMath stage.
///      Reverts propagate from dependencies:
///      - anchorGrowth == 0 → FullMath div-by-zero
///      - ratio overflows uint256 → FullMath revert
/// @param currentGrowth The later (larger) cumulative growth value
/// @param anchorGrowth The earlier (smaller) cumulative growth value
/// @return sqrtPriceX96 The Q64.96 fixed-point square-root of the growth ratio.
function growthToSqrtPriceX96(uint208 currentGrowth, uint208 anchorGrowth)
    pure
    returns (uint160 sqrtPriceX96)
{
    uint256 ratioQ128 =
        FullMath.mulDiv(uint256(currentGrowth), FixedPoint128.Q128, uint256(anchorGrowth));
    uint256 sqrtRatioX64 = FixedPointMathLib.sqrt(ratioQ128);
    sqrtPriceX96 = uint160(sqrtRatioX64 << 32);
}

/// @notice Converts a cumulative growth ratio into a Uniswap V4 tick.
/// @dev Composes growthToSqrtPriceX96 + TickMath.getTickAtSqrtPrice.
///      Reverts if sqrtPriceX96 is outside TickMath's valid range.
/// @param currentGrowth The later (larger) cumulative growth value
/// @param anchorGrowth The earlier (smaller) cumulative growth value
/// @return tick The Uniswap V4 tick corresponding to the growth ratio.
function growthToTick(uint208 currentGrowth, uint208 anchorGrowth) pure returns (int24 tick) {
    tick = TickMath.getTickAtSqrtPrice(growthToSqrtPriceX96(currentGrowth, anchorGrowth));
}
