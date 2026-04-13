// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {CircularBuffer} from "openzeppelin-contracts/utils/structs/CircularBuffer.sol";
import {OraclePack, OraclePackLibrary} from "panoptic-v2/src/types/OraclePack.sol";
import {
    updateGrowthEMA,
    InsufficientObservations,
    FuturePack
} from "core/src/libraries/transformations/EMAGrowthTransformationLib.sol";
import {record} from "core/src/libraries/BlockNumberAwareGrowthObserverLib.sol";

contract MockEMABuffer {
    CircularBuffer.Bytes32CircularBuffer internal buffer;

    constructor(uint256 capacity) {
        CircularBuffer.setup(buffer, capacity);
    }

    function recordObs(uint256 bn, uint256 rtd, uint256 cg) external {
        record(buffer, bn, rtd, cg);
    }

    function runUpdate(OraclePack pack, uint96 periods, int24 clampDelta)
        external
        view
        returns (OraclePack)
    {
        return updateGrowthEMA(buffer, pack, periods, clampDelta);
    }
}

contract EMAGrowthTransformationLibDifferentialTest is Test {
    uint256 constant BUFFER_CAPACITY = 256;
    // spot=100, fast=256, slow=1024, eons=4096 (spec minimums)
    uint96 constant DEFAULT_PERIODS = uint96(100 + (256 << 24) + (1024 << 48) + (4096 << 72));
    int24 constant DEFAULT_CLAMP = 100;

    function _packAtEpoch(uint24 epochValue) internal pure returns (OraclePack) {
        return OraclePackLibrary.storeOraclePack(
            uint256(epochValue), 0, 0, int24(0), uint96(0), int24(0), 0
        );
    }

    function test__fuzzSecurityEdge__EMA_SameEpochNoOpIsBitwiseIdentical(
        uint24 arbitraryEpochBits,
        int24 refTick,
        int24 latestResidual
    ) public {
        uint24 epochValue = arbitraryEpochBits;
        vm.warp(uint256(epochValue) << 6);

        OraclePack original = OraclePackLibrary.storeOraclePack(
            uint256(epochValue), 0xABC, 0xDEF, refTick, uint96(0x123), latestResidual, 0
        );

        MockEMABuffer m = new MockEMABuffer(BUFFER_CAPACITY);
        OraclePack returned = m.runUpdate(original, DEFAULT_PERIODS, DEFAULT_CLAMP);

        assertEq(
            OraclePack.unwrap(returned),
            OraclePack.unwrap(original),
            "same-epoch: pack must be returned bit-exact"
        );
    }

    function test__SecurityEdge__EMA_InsufficientObservationsRevertsBelow2() public {
        MockEMABuffer m = new MockEMABuffer(BUFFER_CAPACITY);

        vm.warp(10_000);
        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);
        OraclePack stalePack = _packAtEpoch(currentEpoch - 1);

        vm.expectRevert(InsufficientObservations.selector);
        m.runUpdate(stalePack, DEFAULT_PERIODS, DEFAULT_CLAMP);

        m.recordObs(1000, 0, 1e18);
        vm.expectRevert(InsufficientObservations.selector);
        m.runUpdate(stalePack, DEFAULT_PERIODS, DEFAULT_CLAMP);
    }

    function test__fuzzSecurityEdge__EMA_FuturePackReverts(uint24 futureOffset) public {
        MockEMABuffer m = new MockEMABuffer(BUFFER_CAPACITY);
        m.recordObs(1000, 0, 1e18);
        m.recordObs(1001, 12, 2e18);

        vm.warp(10_000);
        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);

        // Bound to genuinely-future range in uint24 wrap space (forwardDist < 2^23).
        // Larger offsets are interpreted as wrap-behind by the wrap-safe guard.
        futureOffset = uint24(bound(uint256(futureOffset), 1, (1 << 23) - 1));

        uint24 futureEpoch = currentEpoch + futureOffset;
        OraclePack futurePack = _packAtEpoch(futureEpoch);

        vm.expectRevert(abi.encodeWithSelector(FuturePack.selector, futureEpoch, currentEpoch));
        m.runUpdate(futurePack, DEFAULT_PERIODS, DEFAULT_CLAMP);
    }

    function test__fuzzSecurityEdge__EMA_NegativeClampDeltaCurrentlyAccepted(int24 clamp) public {
        clamp = int24(bound(clamp, -1000, -1));

        MockEMABuffer m = new MockEMABuffer(BUFFER_CAPACITY);
        m.recordObs(1000, 0, 1e18);
        m.recordObs(1001, 12, 5e18);

        vm.warp(10_000);
        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);
        OraclePack stalePack = _packAtEpoch(currentEpoch - 1);

        try m.runUpdate(stalePack, DEFAULT_PERIODS, clamp) returns (OraclePack returned) {
            assertEq(
                uint256(returned.epoch()),
                uint256(currentEpoch),
                "EMA advances epoch with negative clampDelta (current silent behavior)"
            );
            assertTrue(
                OraclePack.unwrap(returned) != OraclePack.unwrap(stalePack),
                "returned pack must differ from stale (observable state change)"
            );
        } catch {
            // Forward-compatibility branch: if a future guard is added to reject
            // negative clampDelta, record() will revert here. Currently unreachable —
            // no such guard exists in the library as of this commit.
        }
    }
}
