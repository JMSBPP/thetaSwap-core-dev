// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {FixedPoint128} from "@uniswap/v4-core/src/libraries/FixedPoint128.sol";
import {LiquidityMath} from "@uniswap/v4-core/src/libraries/LiquidityMath.sol";

/// @dev Underwriter position in the insurance CFMM.
///      Mirrors V4's Position.State but with a single premium dimension
///      (PLPs pay premiums → underwriters earn them).
///
///      Keyed by keccak256(owner, tickLower, tickUpper, salt) — same as V4.
struct UnderwriterPosition {
    /// @dev Liquidity owned by this underwriter in the tick range.
    uint128 liquidity;
    /// @dev Premium growth per unit of liquidity, inside the position's tick range,
    ///      as of the last update. Used to compute accrued premiums on next touch.
    uint256 premiumGrowthInsideLastX128;
}

// ── Errors ──────────────────────────────────────────────────────────────

error UnderwriterPosition__CannotUpdateEmpty();

// ── Position Key ────────────────────────────────────────────────────────

/// @dev Compute the position key. Same layout as V4's Position.calculatePositionKey.
function calculatePositionKey(
    address owner,
    int24 tickLower,
    int24 tickUpper,
    bytes32 salt
) pure returns (bytes32 positionKey) {
    assembly ("memory-safe") {
        let fmp := mload(0x40)
        mstore(add(fmp, 0x26), salt)
        mstore(add(fmp, 0x06), tickUpper)
        mstore(add(fmp, 0x03), tickLower)
        mstore(fmp, owner)
        positionKey := keccak256(add(fmp, 0x0c), 0x3a)
        mstore(add(fmp, 0x40), 0)
        mstore(add(fmp, 0x20), 0)
        mstore(fmp, 0)
    }
}

// ── Lookup ──────────────────────────────────────────────────────────────

/// @dev Retrieve a position from the mapping by owner and tick range.
function get(
    mapping(bytes32 => UnderwriterPosition) storage self,
    address owner,
    int24 tickLower,
    int24 tickUpper,
    bytes32 salt
) view returns (UnderwriterPosition storage position) {
    bytes32 key = calculatePositionKey(owner, tickLower, tickUpper, salt);
    position = self[key];
}

// ── Update ──────────────────────────────────────────────────────────────

/// @dev Update an underwriter position: adjust liquidity and collect accrued premiums.
///      Mirrors V4's Position.update but with a single premium dimension.
///
///      On liquidityDelta == 0: "poke" to collect premiums (reverts if empty).
///      On liquidityDelta != 0: add/remove liquidity and collect premiums.
///
///      Returns premiumOwed: the amount of premium earned since last update.
///      Uses unchecked subtraction on premiumGrowthInside (overflow wraps, V4 convention).
function update(
    UnderwriterPosition storage self,
    int128 liquidityDelta,
    uint256 premiumGrowthInsideX128
) returns (uint256 premiumOwed) {
    uint128 liquidity = self.liquidity;

    if (liquidityDelta == 0) {
        if (liquidity == 0) revert UnderwriterPosition__CannotUpdateEmpty();
    } else {
        self.liquidity = LiquidityMath.addDelta(liquidity, liquidityDelta);
    }

    unchecked {
        premiumOwed = FullMath.mulDiv(
            premiumGrowthInsideX128 - self.premiumGrowthInsideLastX128,
            liquidity,
            FixedPoint128.Q128
        );
    }

    self.premiumGrowthInsideLastX128 = premiumGrowthInsideX128;
}
