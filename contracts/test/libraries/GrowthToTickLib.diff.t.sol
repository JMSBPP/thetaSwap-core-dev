// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {growthToTick} from "core/src/libraries/GrowthToTickLib.sol";
import {FullMath} from "v4-core/src/libraries/FullMath.sol";
import {FixedPointMathLib} from "solady/src/utils/FixedPointMathLib.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {FixedPoint128} from "v4-core/src/libraries/FixedPoint128.sol";

contract GrowthToTickLibDifferentialTest is Test {
    function externalGrowthToTick(uint208 cg, uint208 ag) external pure returns (int24) {
        return growthToTick(cg, ag);
    }

    function test__fuzzBTT__GrowthToTick_TickMathRoundTripConsistency(
        uint256 currentGrowth,
        uint256 anchorGrowth
    ) public {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max);
        currentGrowth = bound(currentGrowth, anchorGrowth, type(uint208).max);
        vm.assume(currentGrowth / anchorGrowth < (1 << 128));

        int24 tick = growthToTick(uint208(currentGrowth), uint208(anchorGrowth));

        uint160 sqrtAtTick = TickMath.getSqrtPriceAtTick(tick);

        uint256 ratioQ128 =
            FullMath.mulDiv(currentGrowth, FixedPoint128.Q128, anchorGrowth);
        uint256 computedSqrtPriceX96 = FixedPointMathLib.sqrt(ratioQ128) << 32;

        assertLe(sqrtAtTick, computedSqrtPriceX96, "tick floor violated");

        if (tick < TickMath.MAX_TICK) {
            uint160 sqrtAtNextTick = TickMath.getSqrtPriceAtTick(tick + 1);
            assertLt(computedSqrtPriceX96, sqrtAtNextTick, "tick should be tighter");
        }
    }

    function test__fuzzBTT__GrowthToTick_Identity(uint256 anchorGrowth) public pure {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max);

        int24 tick = growthToTick(uint208(anchorGrowth), uint208(anchorGrowth));

        assertEq(tick, 0, "identity: equal growths should map to tick 0");
    }

    function test__fuzzBTT__GrowthToTick_Monotonicity(uint256 anchorGrowth, uint256 deltaSeed) public {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max);
        uint256 a1 = bound(deltaSeed, anchorGrowth, type(uint208).max);
        vm.assume(a1 / anchorGrowth < (1 << 128));
        uint256 a2 = bound(uint256(keccak256(abi.encode(deltaSeed))), a1, type(uint208).max);
        vm.assume(a2 / anchorGrowth < (1 << 128));

        int24 t1 = growthToTick(uint208(a1), uint208(anchorGrowth));
        int24 t2 = growthToTick(uint208(a2), uint208(anchorGrowth));

        assertLe(t1, t2, "monotonicity violated: larger growth gave smaller tick");
    }

    function test__fuzzBTT__GrowthToTick_NonNegativity(
        uint256 currentGrowth,
        uint256 anchorGrowth
    ) public {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max);
        currentGrowth = bound(currentGrowth, anchorGrowth, type(uint208).max);
        vm.assume(currentGrowth / anchorGrowth < (1 << 128));

        int24 tick = growthToTick(uint208(currentGrowth), uint208(anchorGrowth));

        assertGe(tick, 0, "non-negativity: ratio >= 1 should map to tick >= 0");
    }

    function test__fuzzBTT__GrowthToTick_AnchorScalingInvariance(
        uint256 currentGrowth,
        uint256 anchorGrowth,
        uint256 kSeed
    ) public {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max / 2);
        currentGrowth = bound(currentGrowth, anchorGrowth, type(uint208).max / 2);
        vm.assume(currentGrowth / anchorGrowth < (1 << 128));

        uint256 maxK = type(uint208).max / currentGrowth;
        vm.assume(maxK > 1);
        uint256 k = bound(kSeed, 2, maxK);

        int24 tOriginal = growthToTick(uint208(currentGrowth), uint208(anchorGrowth));
        int24 tScaled = growthToTick(uint208(currentGrowth * k), uint208(anchorGrowth * k));

        int256 diff = int256(tOriginal) - int256(tScaled);
        if (diff < 0) diff = -diff;
        assertLe(diff, 1, "anchor-scaling invariance drift > 1 tick");
    }

    function test__fuzzBTT__GrowthToTick_ZeroAnchorReverts(uint256 currentGrowth) public {
        currentGrowth = bound(currentGrowth, 0, type(uint208).max);

        try this.externalGrowthToTick(uint208(currentGrowth), 0) {
            fail();
        } catch (bytes memory reason) {
            assertEq(reason.length, 0, "expected FullMath bare require (empty revert) for zero anchor");
        }
    }

    function test__fuzzBTT__GrowthToTick_ZeroCurrentReverts(uint256 anchorGrowth) public {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max);

        vm.expectRevert(abi.encodeWithSelector(TickMath.InvalidSqrtPrice.selector, uint160(0)));
        this.externalGrowthToTick(0, uint208(anchorGrowth));
    }

    function test__fuzzSecurityEdge__GrowthToTick_InvertedArgsProducesNegativeTick(
        uint256 latestGrowth,
        uint256 oldestGrowth
    ) public pure {
        oldestGrowth = bound(oldestGrowth, 2, 1 << 60);
        latestGrowth = bound(latestGrowth, 1, oldestGrowth - 1);

        int24 tickNormal = growthToTick(uint208(oldestGrowth), uint208(latestGrowth));
        int24 tickInverted = growthToTick(uint208(latestGrowth), uint208(oldestGrowth));

        assertGe(tickNormal, 0, "normal direction non-negative");
        assertLt(tickInverted, 0, "inverted direction negative");

        int24 sum = tickNormal + tickInverted;
        int24 absSum = sum >= 0 ? sum : -sum;
        assertLe(absSum, 1, "symmetry drift > 1 tick");
    }

    function test__fuzzSecurityEdge__GrowthToTick_Stage1OverflowReverts(
        uint256 currentGrowth,
        uint256 anchorGrowth
    ) public {
        anchorGrowth = bound(anchorGrowth, 1, (1 << 80) - 1);

        uint256 minOverflowCurrent = anchorGrowth * (1 << 128);
        vm.assume(minOverflowCurrent < type(uint208).max);

        currentGrowth = bound(currentGrowth, minOverflowCurrent + 1, type(uint208).max);

        try this.externalGrowthToTick(uint208(currentGrowth), uint208(anchorGrowth)) {
            fail();
        } catch (bytes memory reason) {
            assertEq(reason.length, 0, "expected FullMath bare require (empty revert) for Stage 1 overflow");
        }
    }

    function test__fuzzSecurityEdge__GrowthToTick_SqrtPriceX96FitsInUint160(
        uint256 currentGrowth,
        uint256 anchorGrowth
    ) public {
        anchorGrowth = bound(anchorGrowth, 1, type(uint208).max);
        currentGrowth = bound(currentGrowth, anchorGrowth, type(uint208).max);
        vm.assume(currentGrowth / anchorGrowth < (1 << 128));

        uint256 ratioQ128 = FullMath.mulDiv(currentGrowth, FixedPoint128.Q128, anchorGrowth);
        uint256 sqrtPriceX96 = FixedPointMathLib.sqrt(ratioQ128) << 32;

        assertLt(sqrtPriceX96, 1 << 160, "sqrtPriceX96 exceeded uint160 -- cast would truncate");
    }

    function test__fuzzSecurityEdge__GrowthToTick_NearMaxSqrtPriceCliff(
        uint256 anchorGrowth,
        uint256 currentGrowth
    ) public {
        anchorGrowth = bound(anchorGrowth, 1, 1 << 80);
        uint256 upperCurrent = anchorGrowth << 128 > type(uint208).max
            ? type(uint208).max
            : (anchorGrowth << 128) - 1;
        currentGrowth = bound(currentGrowth, anchorGrowth << 127, upperCurrent);
        vm.assume(currentGrowth / anchorGrowth < (1 << 128));

        uint256 ratioQ128 = FullMath.mulDiv(currentGrowth, FixedPoint128.Q128, anchorGrowth);
        uint256 sqrtPriceX96 = FixedPointMathLib.sqrt(ratioQ128) << 32;

        try this.externalGrowthToTick(uint208(currentGrowth), uint208(anchorGrowth)) returns (int24 tick) {
            assertLt(sqrtPriceX96, uint256(TickMath.MAX_SQRT_PRICE), "returned tick but sqrtPrice >= MAX");
            assertLe(tick, TickMath.MAX_TICK, "tick exceeded MAX_TICK");
        } catch {
            assertGe(sqrtPriceX96, uint256(TickMath.MAX_SQRT_PRICE), "reverted but sqrtPrice < MAX");
        }
    }
}
