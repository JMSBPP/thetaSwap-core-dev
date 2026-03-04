// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FixedPoint128} from "@uniswap/v4-core/src/libraries/FixedPoint128.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {
    UnderwriterPosition,
    UnderwriterPosition__CannotUpdateEmpty,
    calculatePositionKey, get, update
} from "../../../src/theta-swap-insurance/types/UnderwriterPositionMod.sol";

contract UnderwriterPositionTest is Test {
    mapping(bytes32 => UnderwriterPosition) positions;

    // ── calculatePositionKey ────────────────────────────────────────

    // Deterministic: same inputs → same key
    function testFuzz_positionKeyDeterministic(
        address owner, int24 tickLower, int24 tickUpper, bytes32 salt
    ) public pure {
        bytes32 k1 = calculatePositionKey(owner, tickLower, tickUpper, salt);
        bytes32 k2 = calculatePositionKey(owner, tickLower, tickUpper, salt);
        assertEq(k1, k2);
    }

    // Different owners → different keys
    function testFuzz_positionKeyDifferentOwners(
        address owner1, address owner2, int24 tickLower, int24 tickUpper, bytes32 salt
    ) public pure {
        vm.assume(owner1 != owner2);
        bytes32 k1 = calculatePositionKey(owner1, tickLower, tickUpper, salt);
        bytes32 k2 = calculatePositionKey(owner2, tickLower, tickUpper, salt);
        assertTrue(k1 != k2);
    }

    // Different tick ranges → different keys
    function testFuzz_positionKeyDifferentTicks(
        address owner, int24 tickLower1, int24 tickLower2, int24 tickUpper, bytes32 salt
    ) public pure {
        vm.assume(tickLower1 != tickLower2);
        bytes32 k1 = calculatePositionKey(owner, tickLower1, tickUpper, salt);
        bytes32 k2 = calculatePositionKey(owner, tickLower2, tickUpper, salt);
        assertTrue(k1 != k2);
    }

    // ── get ──────────────────────────────────────────────────────────

    // Default position is zero
    function test_getDefaultIsZero() public view {
        UnderwriterPosition storage pos = get(positions, address(0xBEEF), -100, 100, bytes32(0));
        assertEq(pos.liquidity, 0);
        assertEq(pos.premiumGrowthInsideLastX128, 0);
    }

    // ── update: add liquidity ───────────────────────────────────────

    // First add sets liquidity
    function test_updateAddLiquidity() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        uint256 premiumOwed = update(positions[key], int128(1e18), 0);
        assertEq(premiumOwed, 0);
        assertEq(positions[key].liquidity, 1e18);
    }

    // Add then add again accumulates
    function test_updateAddTwice() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(1e18), 0);
        update(positions[key], int128(1e18), 0);
        assertEq(positions[key].liquidity, 2e18);
    }

    // ── update: remove liquidity ────────────────────────────────────

    // Add then remove returns to zero
    function test_updateAddThenRemove() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(1e18), 0);
        update(positions[key], -int128(1e18), 0);
        assertEq(positions[key].liquidity, 0);
    }

    // Remove more than available reverts (SafeCast overflow in LiquidityMath)
    function test_updateRemoveTooMuchReverts() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(1e18), 0);
        vm.expectRevert(SafeCast.SafeCastOverflow.selector);
        this.externalUpdate(key, -int128(2e18), 0);
    }

    // ── update: poke (liquidityDelta == 0) ──────────────────────────

    // Poke empty position reverts
    function test_updatePokeEmptyReverts() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        vm.expectRevert(UnderwriterPosition__CannotUpdateEmpty.selector);
        this.externalUpdate(key, 0, 0);
    }

    // Poke with premium growth collects premiums
    function test_updatePokeCollectsPremium() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        // Add 1e18 liquidity at premiumGrowth = 0
        update(positions[key], int128(1e18), 0);

        // Premium growth increased by 1 full unit (Q128)
        uint256 growth = FixedPoint128.Q128;
        uint256 premiumOwed = update(positions[key], 0, growth);

        // premiumOwed = (growth - 0) * 1e18 / Q128 = 1e18
        assertEq(premiumOwed, 1e18);
        assertEq(positions[key].premiumGrowthInsideLastX128, growth);
    }

    // ── update: premium accrual math ────────────────────────────────

    // Premium accrual proportional to liquidity
    function testFuzz_premiumProportionalToLiquidity(
        uint64 liquidity,
        uint64 growthDelta
    ) public {
        vm.assume(liquidity > 0);
        vm.assume(growthDelta > 0);

        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(uint128(liquidity)), 0);

        uint256 growth = uint256(growthDelta) * FixedPoint128.Q128 / 1e18;
        uint256 premiumOwed = update(positions[key], 0, growth);

        // premiumOwed = growth * liquidity / Q128
        uint256 expected = (uint256(growth) * uint256(liquidity)) / FixedPoint128.Q128;
        assertEq(premiumOwed, expected);
    }

    // Zero growth → zero premium
    function testFuzz_zeroPremiumOnZeroGrowth(uint64 liquidity) public {
        vm.assume(liquidity > 0);
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(uint128(liquidity)), 0);
        uint256 premiumOwed = update(positions[key], 0, 0);
        assertEq(premiumOwed, 0);
    }

    // Snapshot updates correctly across multiple pokes
    function test_snapshotUpdatesAcrossPokes() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(1e18), 0);

        // First poke: growth from 0 to Q128
        uint256 g1 = FixedPoint128.Q128;
        uint256 p1 = update(positions[key], 0, g1);
        assertEq(p1, 1e18);

        // Second poke: growth from Q128 to 2*Q128
        uint256 g2 = 2 * FixedPoint128.Q128;
        uint256 p2 = update(positions[key], 0, g2);
        assertEq(p2, 1e18);

        // Snapshot is now at 2*Q128
        assertEq(positions[key].premiumGrowthInsideLastX128, g2);
    }

    // Premium collected on remove (liquidityDelta < 0)
    function test_premiumCollectedOnRemove() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        update(positions[key], int128(1e18), 0);

        uint256 growth = FixedPoint128.Q128;
        uint256 premiumOwed = update(positions[key], -int128(1e18), growth);

        assertEq(premiumOwed, 1e18);
        assertEq(positions[key].liquidity, 0);
    }

    // ── update: overflow wrapping (V4 convention) ───────────────────

    // Premium growth wraps around (unchecked subtraction)
    function test_premiumGrowthOverflowWraps() public {
        bytes32 key = calculatePositionKey(address(this), -100, 100, bytes32(0));
        // Start at near-max growth
        uint256 startGrowth = type(uint256).max - FixedPoint128.Q128 + 1;
        update(positions[key], int128(1e18), startGrowth);

        // Wrap around: new growth < old growth due to overflow
        uint256 endGrowth = FixedPoint128.Q128 - 1;
        uint256 premiumOwed = update(positions[key], 0, endGrowth);

        // Delta wraps: endGrowth - startGrowth = 2*Q128 - 2 (unchecked)
        // premiumOwed = (2*Q128 - 2) * 1e18 / Q128 ≈ 2e18
        uint256 expectedDelta;
        unchecked {
            expectedDelta = endGrowth - startGrowth;
        }
        uint256 expected = (expectedDelta * 1e18) / FixedPoint128.Q128;
        assertEq(premiumOwed, expected);
    }

    // ── Helper for expectRevert on free functions ────────────────────

    function externalUpdate(
        bytes32 key, int128 liquidityDelta, uint256 premiumGrowthInsideX128
    ) external returns (uint256) {
        return update(positions[key], liquidityDelta, premiumGrowthInsideX128);
    }
}
