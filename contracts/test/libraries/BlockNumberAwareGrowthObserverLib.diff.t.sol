// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {BaseForkTest} from "anstrong-test/_helpers/BaseForkTest.t.sol";
import {CircularBuffer} from "openzeppelin-contracts/utils/structs/CircularBuffer.sol";
import {console2} from "forge-std/console2.sol";
import {
    record,
    observeAt,
    latestObservation,
    oldestObservation,
    observationCount
} from "core/src/libraries/BlockNumberAwareGrowthObserverLib.sol";
import {GrowthObservation} from "core/src/types/GrowthObservation.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";
import {
    AccumulatorRow,
    rangeArgs,
    decodeRange
} from "anstrong-test/_ffi_utils/ffiLib.sol";

contract MockBlockNumberAware {
    CircularBuffer.Bytes32CircularBuffer internal buffer;

    constructor(uint256 capacity) {
        CircularBuffer.setup(buffer, capacity);
    }

    function recordObs(uint256 _blockNumber, uint256 _relTimeDelta, uint256 _cumGrowth) external {
        record(buffer, _blockNumber, _relTimeDelta, _cumGrowth);
    }

    function observeAtTarget(uint32 targetBlock) external view returns (GrowthObservation) {
        return observeAt(buffer, targetBlock);
    }

    function latest() external view returns (GrowthObservation) {
        return latestObservation(buffer);
    }

    function oldest() external view returns (GrowthObservation) {
        return oldestObservation(buffer);
    }

    function count() external view returns (uint256) {
        return observationCount(buffer);
    }

    function rawAt(uint256 i) external view returns (GrowthObservation) {
        return GrowthObservation.wrap(CircularBuffer.last(buffer, i));
    }
}

contract BlockNumberAwareGrowthObserverLibDifferentialTest is BaseForkTest {
    uint256 constant BUFFER_CAPACITY = 256;
    uint256 constant FIRST_OBSERVATION_TIME_DELTA = 0;

    MockBlockNumberAware mock;

    function setUp() public override {
        super.setUp();
        if (!forked) return;
        mock = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(mock));
    }

    function test__fuzzDifferential__ObserveAtFullBufferBinarySearchWorstCase() public onlyForked {
        AccumulatorRow[] memory rows = decodeRange(ffiPython(rangeArgs(vm, 0, 256)));

        for (uint256 i; i < rows.length; ++i) {
            mock.recordObs(rows[i].blockNumber, FIRST_OBSERVATION_TIME_DELTA, rows[i].globalGrowth);
        }

        // Target the 2nd-oldest block — forces binary search to traverse maximum depth
        // on a descending-index buffer. Targeting rows[1] (2nd-newest) would hit in 1-2 iterations.
        uint32 target = uint32(rows[rows.length - 2].blockNumber);

        uint256 gasBefore = gasleft();
        GrowthObservation found = mock.observeAtTarget(target);
        uint256 gasUsed = gasBefore - gasleft();

        uint256 spanSeconds = rows[rows.length - 1].blockTimestamp - rows[0].blockTimestamp;

        console2.log("observeAt gasUsed:", gasUsed);
        console2.log("buffer span (seconds):", spanSeconds);
        console2.log("buffer span (minutes):", spanSeconds / 60);

        assertEq(uint256(found.blockNumber()), rows[rows.length - 2].blockNumber, "observeAt returned wrong row");
        assertLt(gasUsed, 18_000, "observeAt gas regressed beyond expected budget");
        assertGt(spanSeconds, 1800, "buffer span below 30 min floor");
    }

    function test__fuzzDifferential__ObserveAtProductionCadence30MinCoverage() public onlyForked {
        uint256 BLOCK_TIME_SECONDS = 12;

        MockBlockNumberAware denseMock = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(denseMock));

        uint256 startBlock = block.number;
        uint256 startTimestamp = block.timestamp;

        for (uint256 i; i < BUFFER_CAPACITY; ++i) {
            vm.roll(startBlock + i);
            vm.warp(startTimestamp + i * BLOCK_TIME_SECONDS);

            uint256 relTimeDelta = i == 0 ? 0 : BLOCK_TIME_SECONDS;
            uint256 growth = (i + 1) * 1e18;
            denseMock.recordObs(block.number, relTimeDelta, growth);
        }

        uint32 target = uint32(startBlock + 1);

        uint256 gasBefore = gasleft();
        GrowthObservation found = denseMock.observeAtTarget(target);
        uint256 gasUsed = gasBefore - gasleft();

        uint32 storedOldest = denseMock.oldest().blockNumber();
        uint32 storedNewest = denseMock.latest().blockNumber();
        uint256 storedBlockSpan = uint256(storedNewest - storedOldest);
        uint256 storedTimeSpanSeconds = storedBlockSpan * BLOCK_TIME_SECONDS;

        console2.log("production observeAt gasUsed:", gasUsed);
        console2.log("stored buffer block span:", storedBlockSpan);
        console2.log("stored buffer time span (seconds):", storedTimeSpanSeconds);
        console2.log("stored buffer time span (minutes):", storedTimeSpanSeconds / 60);

        assertEq(uint256(found.blockNumber()), startBlock + 1, "observeAt wrong row");
        assertLt(gasUsed, 18_000, "production observeAt gas regressed");
        assertEq(denseMock.count(), BUFFER_CAPACITY, "buffer did not fill to capacity");
        assertGe(storedTimeSpanSeconds, 1800, "stored buffer span below 30 min floor");
    }

    function test__fuzzDifferential__ObserveAtPostWrapGasStability(uint256 wrapSeed) public onlyForked {
        MockBlockNumberAware wrapMock = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(wrapMock));

        uint256 totalPushes = bound(wrapSeed, BUFFER_CAPACITY + 1, BUFFER_CAPACITY * 10);

        uint256 startBlock = block.number;
        uint256 startTimestamp = block.timestamp;

        for (uint256 i; i < totalPushes; ++i) {
            vm.roll(startBlock + i);
            vm.warp(startTimestamp + i * 12);

            uint256 relTimeDelta = i == 0 ? 0 : 12;
            uint256 growth = (i + 1) * 1e18;
            wrapMock.recordObs(block.number, relTimeDelta, growth);
        }

        uint256 oldestSurvivingIdx = totalPushes - BUFFER_CAPACITY;
        uint32 target = uint32(startBlock + oldestSurvivingIdx + 1);

        uint256 gasBefore = gasleft();
        GrowthObservation found = wrapMock.observeAtTarget(target);
        uint256 gasUsed = gasBefore - gasleft();

        console2.log("totalPushes:", totalPushes);
        console2.log("post-wrap observeAt gasUsed:", gasUsed);

        assertEq(
            uint256(found.blockNumber()),
            uint256(startBlock + oldestSurvivingIdx + 1),
            "observeAt returned wrong row after wrap"
        );
        assertLt(gasUsed, 18_000, "post-wrap gas regressed");
    }

    function test__fuzzSecurityEdge__RelativeTimeDeltaInRangeRoundTrips(uint256 relTimeDelta) public onlyForked {
        relTimeDelta = bound(relTimeDelta, 0, type(uint16).max);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(1000, 0, 1e18);
        m.recordObs(1001, relTimeDelta, 2e18);

        assertEq(
            uint256(m.latest().relativeTimeDelta()),
            relTimeDelta,
            "relativeTimeDelta round-trip failed"
        );
    }

    function test__fuzzSecurityEdge__RelativeTimeDeltaOverflowReverts(uint256 relTimeDelta) public onlyForked {
        relTimeDelta = bound(relTimeDelta, uint256(type(uint16).max) + 1, type(uint256).max);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(1000, 0, 1e18);

        vm.expectRevert(SafeCastLib.Overflow.selector);
        m.recordObs(1001, relTimeDelta, 2e18);
    }

    function test__fuzzSecurityEdge__BlockNumberInRangeRoundTrips(uint256 bn) public onlyForked {
        bn = bound(bn, 0, type(uint32).max);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(bn, 0, 1e18);

        assertEq(
            uint256(m.latest().blockNumber()),
            bn,
            "blockNumber round-trip failed"
        );
    }

    function test__fuzzSecurityEdge__BlockNumberOverflowReverts(uint256 bn) public onlyForked {
        bn = bound(bn, uint256(type(uint32).max) + 1, type(uint256).max);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        vm.expectRevert(SafeCastLib.Overflow.selector);
        m.recordObs(bn, 0, 1e18);
    }

    function test__fuzzSecurityEdge__ObserveAtExactOldestBoundaryPostWrap(uint256 wrapSeed) public onlyForked {
        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        uint256 totalPushes = bound(wrapSeed, BUFFER_CAPACITY + 1, BUFFER_CAPACITY * 4);
        uint256 startBlock = block.number;

        for (uint256 i; i < totalPushes; ++i) {
            vm.roll(startBlock + i);
            vm.warp(block.timestamp + 12);
            m.recordObs(block.number, i == 0 ? 0 : 12, (i + 1) * 1e18);
        }

        uint256 oldestSurvivingIdx = totalPushes - BUFFER_CAPACITY;
        uint32 oldestBlock = uint32(startBlock + oldestSurvivingIdx);

        GrowthObservation atBoundary = m.observeAtTarget(oldestBlock);
        assertEq(uint256(atBoundary.blockNumber()), uint256(oldestBlock), "at-boundary mismatch");

        vm.expectRevert(
            abi.encodeWithSignature("ObservationExpired(uint32,uint32)", oldestBlock - 1, oldestBlock)
        );
        m.observeAtTarget(oldestBlock - 1);
    }

    function test__fuzzBTT__RecordMonotonicity_DescendingBlocksSilentlySkipped(
        uint256 firstBlock,
        uint256 secondBlock
    ) public onlyForked {
        firstBlock = bound(firstBlock, 1, type(uint32).max - 1);
        secondBlock = bound(secondBlock, 0, firstBlock);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(firstBlock, 7, 1e18);
        uint256 countBefore = m.count();
        GrowthObservation originalLatest = m.latest();

        m.recordObs(secondBlock, 12, 2e18);

        assertEq(m.count(), countBefore, "stale/duplicate should not increase count");
        assertEq(
            GrowthObservation.unwrap(m.latest()),
            GrowthObservation.unwrap(originalLatest),
            "stale record must not modify any field of latest"
        );
    }

    function test__fuzzBTT__CountSaturatesAtCapacity(uint256 pushCountSeed) public onlyForked {
        uint256 pushCount = bound(pushCountSeed, 1, BUFFER_CAPACITY * 5);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        uint256 startBlock = block.number;
        for (uint256 i; i < pushCount; ++i) {
            m.recordObs(startBlock + i, i == 0 ? 0 : 12, (i + 1) * 1e18);
        }

        uint256 expectedCount = pushCount < BUFFER_CAPACITY ? pushCount : BUFFER_CAPACITY;
        assertEq(m.count(), expectedCount, "count mismatch");
        assertLe(m.count(), BUFFER_CAPACITY, "count exceeded capacity");
    }

    function test__BTT__EmptyBufferBehavior() public onlyForked {
        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        assertEq(m.count(), 0, "empty buffer count should be 0");

        vm.expectRevert(abi.encodeWithSignature("EmptyBuffer()"));
        m.latest();

        vm.expectRevert(abi.encodeWithSignature("EmptyBuffer()"));
        m.oldest();
    }

    function test__fuzzBTT__RecordThenReadRoundTrip(
        uint256 bn,
        uint256 relTimeDelta,
        uint256 growth
    ) public onlyForked {
        bn = bound(bn, 1, type(uint32).max);
        relTimeDelta = bound(relTimeDelta, 0, type(uint16).max);
        growth = bound(growth, 0, type(uint208).max);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(bn, relTimeDelta, growth);

        GrowthObservation lat = m.latest();
        GrowthObservation old = m.oldest();
        GrowthObservation at = m.observeAtTarget(uint32(bn));

        assertEq(uint256(lat.blockNumber()), bn, "latest.blockNumber");
        assertEq(uint256(lat.relativeTimeDelta()), relTimeDelta, "latest.relTimeDelta");
        assertEq(uint256(lat.cumulativeGrowth()), growth, "latest.growth");

        assertEq(GrowthObservation.unwrap(lat), GrowthObservation.unwrap(old), "single obs: latest == oldest");
        assertEq(GrowthObservation.unwrap(lat), GrowthObservation.unwrap(at), "observeAt exact match");
    }

    function test__fuzzBTT__DescendingBlockOrderingInvariant(uint256 pushCountSeed) public onlyForked {
        uint256 pushCount = bound(pushCountSeed, 2, BUFFER_CAPACITY * 2);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        uint256 startBlock = block.number;
        for (uint256 i; i < pushCount; ++i) {
            m.recordObs(startBlock + i, i == 0 ? 0 : 12, (i + 1) * 1e18);
        }

        uint256 c = m.count();
        uint32 prevBlock = m.rawAt(0).blockNumber();

        for (uint256 i = 1; i < c; ++i) {
            uint32 currBlock = m.rawAt(i).blockNumber();
            assertLt(currBlock, prevBlock, "ordering not strictly descending");
            prevBlock = currBlock;
        }
    }

    function test__fuzzBTT__ObserveAtMonotonicity(uint256 targetSeedA, uint256 targetSeedB) public onlyForked {
        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        uint256 startBlock = block.number;
        for (uint256 i; i < BUFFER_CAPACITY; ++i) {
            m.recordObs(startBlock + i, i == 0 ? 0 : 12, (i + 1) * 1e18);
        }

        uint32 oldestBlock = m.oldest().blockNumber();
        uint32 newestBlock = m.latest().blockNumber();

        uint32 t1 = uint32(bound(targetSeedA, oldestBlock, newestBlock));
        uint32 t2 = uint32(bound(targetSeedB, oldestBlock, newestBlock));
        if (t1 > t2) (t1, t2) = (t2, t1);

        GrowthObservation r1 = m.observeAtTarget(t1);
        GrowthObservation r2 = m.observeAtTarget(t2);

        assertLe(r1.blockNumber(), r2.blockNumber(), "observeAt not monotonic");
    }

    function test__fuzzBTT__RecordIdempotence_SameBlockDuplicateSkipped(uint256 bn) public onlyForked {
        bn = bound(bn, 1, type(uint32).max);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(bn, 0, 1e18);
        uint256 countAfterFirst = m.count();
        GrowthObservation firstLatest = m.latest();

        m.recordObs(bn, 999, 5e18);

        assertEq(m.count(), countAfterFirst, "duplicate same-block should not increment count");
        assertEq(
            GrowthObservation.unwrap(m.latest()),
            GrowthObservation.unwrap(firstLatest),
            "duplicate should not overwrite latest"
        );
    }

    function test__fuzzSecurityEdge__BinarySearchUnderKeeperSkipPattern(
        uint256 gapSeed,
        uint256 targetSeed
    ) public onlyForked {
        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        uint256 startBlock = block.number;
        uint256 bn = startBlock;

        for (uint256 i; i < BUFFER_CAPACITY; ++i) {
            uint256 gap = 1 + (uint256(keccak256(abi.encode(gapSeed, i))) % 20);
            bn += gap;
            m.recordObs(bn, i == 0 ? 0 : gap * 12, (i + 1) * 1e18);
        }

        uint32 oldestBlock = m.oldest().blockNumber();
        uint32 newestBlock = m.latest().blockNumber();

        uint32 target = uint32(bound(targetSeed, oldestBlock, newestBlock));

        uint256 gasBefore = gasleft();
        GrowthObservation result = m.observeAtTarget(target);
        uint256 gasUsed = gasBefore - gasleft();

        assertLe(result.blockNumber(), target, "result should be <= target");
        assertLt(gasUsed, 18_000, "binary search degraded under gaps");

        uint256 c = m.count();
        for (uint256 i; i < c; ++i) {
            uint32 bn_i = m.rawAt(i).blockNumber();
            if (bn_i > result.blockNumber() && bn_i <= target) {
                fail();
            }
        }
    }

    function test__fuzzSecurityEdge__GrowthDeltaWrapsOnDescendingGrowth(
        uint256 firstGrowth,
        uint256 secondGrowth
    ) public onlyForked {
        firstGrowth = bound(firstGrowth, 1, type(uint208).max);
        secondGrowth = bound(secondGrowth, 0, firstGrowth - 1);

        MockBlockNumberAware m = new MockBlockNumberAware(BUFFER_CAPACITY);
        vm.makePersistent(address(m));

        m.recordObs(1000, 0, firstGrowth);

        try m.recordObs(1001, 12, secondGrowth) {
            assertEq(m.count(), 2, "both obs recorded (record checks block, not growth)");
            GrowthObservation older = m.oldest();
            GrowthObservation newer = m.latest();
            uint208 wrappedDelta = older.growthDelta(newer);
            uint256 expectedWrap = (uint256(1) << 208) - (firstGrowth - secondGrowth);
            assertEq(uint256(wrappedDelta), expectedWrap, "wrap magnitude mismatch");
        } catch {
            // Forward-compat: if record() adds a NonMonotonicGrowth guard (F-04),
            // the second push reverts and only the first observation remains.
            assertEq(m.count(), 1, "non-monotonic growth rejected by record()");
        }
    }
}
