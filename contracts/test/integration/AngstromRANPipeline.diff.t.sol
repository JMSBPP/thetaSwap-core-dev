// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {BaseForkTest} from "anstrong-test/_helpers/BaseForkTest.t.sol";
import {AngstromAccumulatorConsumer} from "core/src/_adapters/AngstromAccumulatorConsumer.sol";
import {IAngstromAuth} from "core/src/interfaces/IAngstromAuth.sol";
import {CircularBuffer} from "openzeppelin-contracts/utils/structs/CircularBuffer.sol";
import {OraclePack, OraclePackLibrary} from "panoptic-v2/src/types/OraclePack.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {console2} from "forge-std/console2.sol";
import "anstrong-test/_fork_references/Ethereum.sol" as EthereumForkData;

import {GrowthObservation} from "core/src/types/GrowthObservation.sol";
import {
    record,
    latestObservation,
    oldestObservation,
    observationCount
} from "core/src/libraries/BlockNumberAwareGrowthObserverLib.sol";
import {growthToTick} from "core/src/libraries/GrowthToTickLib.sol";
import {updateGrowthEMA} from "core/src/libraries/transformations/EMAGrowthTransformationLib.sol";

import {
    AccumulatorRow,
    lenArgs,
    rowArgs,
    rangeArgs,
    decodeLen,
    decodeRow,
    decodeRange
} from "anstrong-test/_ffi_utils/ffiLib.sol";

contract MockRANPipeline {
    CircularBuffer.Bytes32CircularBuffer internal buffer;
    AngstromAccumulatorConsumer public immutable consumer;
    PoolId public immutable poolId;

    constructor(
        uint256 capacity,
        AngstromAccumulatorConsumer _consumer,
        PoolId _poolId
    ) {
        CircularBuffer.setup(buffer, capacity);
        consumer = _consumer;
        poolId = _poolId;
    }

    /// @notice Pulls current globalGrowth from the consumer at block.number
    ///         and records it. Simulates keeper tick from production state.
    function recordFromOnChain(uint256 relTimeDelta) external {
        uint256 cg = consumer.globalGrowth(poolId);
        record(buffer, block.number, relTimeDelta, cg);
    }

    /// @notice Synthetic record path (for adversarial canary tests).
    function recordSynthetic(uint256 bn, uint256 rtd, uint256 cg) external {
        record(buffer, bn, rtd, cg);
    }

    function runEMA(OraclePack pack, uint96 periods, int24 clampDelta)
        external
        view
        returns (OraclePack)
    {
        return updateGrowthEMA(buffer, pack, periods, clampDelta);
    }

    function count() external view returns (uint256) {
        return observationCount(buffer);
    }

    function latest() external view returns (GrowthObservation) {
        return latestObservation(buffer);
    }

    function oldest() external view returns (GrowthObservation) {
        return oldestObservation(buffer);
    }
}

contract AngstromRANPipelineIntegrationTest is BaseForkTest {
    uint256 constant BUFFER_CAPACITY = 256;
    uint96 constant DEFAULT_PERIODS = uint96(100 + (256 << 24) + (1024 << 48) + (4096 << 72));
    int24 constant DEFAULT_CLAMP = 1000;

    AngstromAccumulatorConsumer consumer;
    MockRANPipeline pipeline;

    function setUp() public override {
        super.setUp();
        if (!forked) return;

        consumer = new AngstromAccumulatorConsumer(
            IAngstromAuth(EthereumForkData.AngstromAddresses.ANGSTROM),
            POOL_MANAGER
        );
        vm.makePersistent(address(consumer));

        pipeline = new MockRANPipeline(BUFFER_CAPACITY, consumer, USDC_WETH);
        vm.makePersistent(address(pipeline));
    }

    function test__Integration__PipelineHappyPath(uint256 startIdxSeed) public onlyForked {
        uint256 n = decodeLen(ffiPython(lenArgs()));
        uint256 windowSize = 5;
        uint256 startIdx = bound(startIdxSeed, 0, n - windowSize - 1);

        AccumulatorRow[] memory rows = decodeRange(ffiPython(rangeArgs(vm, startIdx, startIdx + windowSize)));

        for (uint256 i; i < rows.length; ++i) {
            vm.rollFork(rows[i].blockNumber);
            pipeline.recordFromOnChain(i == 0 ? 0 : 12);
        }

        assertEq(pipeline.count(), windowSize, "buffer count");
        GrowthObservation old = pipeline.oldest();
        GrowthObservation lat = pipeline.latest();
        assertEq(uint256(old.blockNumber()), rows[0].blockNumber, "oldest block matches first row");
        assertEq(
            uint256(lat.blockNumber()),
            rows[windowSize - 1].blockNumber,
            "latest block matches last row"
        );
        assertEq(
            uint256(old.cumulativeGrowth()),
            rows[0].globalGrowth,
            "oldest growth matches on-chain"
        );
        assertEq(
            uint256(lat.cumulativeGrowth()),
            rows[windowSize - 1].globalGrowth,
            "latest growth matches on-chain"
        );

        int24 expectedGrowthTick = growthToTick(lat.cumulativeGrowth(), old.cumulativeGrowth());
        assertGe(expectedGrowthTick, 0, "real monotonic growth should yield non-negative tick");

        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);
        OraclePack stalePack = OraclePackLibrary.storeOraclePack(
            uint256(currentEpoch - 1), 0, 0, int24(0), uint96(0), int24(0), 0
        );
        OraclePack updated = pipeline.runEMA(stalePack, DEFAULT_PERIODS, DEFAULT_CLAMP);

        assertEq(pipeline.count(), windowSize, "EMA must not mutate buffer count");
        assertEq(
            uint256(pipeline.latest().cumulativeGrowth()),
            rows[windowSize - 1].globalGrowth,
            "EMA must not mutate buffer contents"
        );
        assertEq(uint256(updated.epoch()), uint256(currentEpoch), "updated pack epoch");
    }

    function test__IntegrationSecurityEdge__C1_ZeroAnchorRevertsEMA() public onlyForked {
        pipeline.recordSynthetic(1000, 0, 0);
        pipeline.recordSynthetic(1001, 12, 1e18);

        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);
        OraclePack stalePack = OraclePackLibrary.storeOraclePack(
            uint256(currentEpoch - 1), 0, 0, int24(0), uint96(0), int24(0), 0
        );

        try pipeline.runEMA(stalePack, DEFAULT_PERIODS, DEFAULT_CLAMP) {
            fail();
        } catch (bytes memory reason) {
            assertEq(reason.length, 0, "expected FullMath bare require (empty revert) for zero anchor");
        }
    }

    function test__IntegrationSecurityEdge__C2_StagnantPoolDoesNotRevertAndTicksEpoch() public onlyForked {
        uint256 stagnantGrowth = 5e30;
        pipeline.recordSynthetic(1000, 0, stagnantGrowth);
        pipeline.recordSynthetic(1001, 12, stagnantGrowth);

        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);
        OraclePack stalePack = OraclePackLibrary.storeOraclePack(
            uint256(currentEpoch - 1), 0, 0, int24(0), uint96(0), int24(0), 0
        );

        OraclePack afterFirst = pipeline.runEMA(stalePack, DEFAULT_PERIODS, DEFAULT_CLAMP);
        assertEq(uint256(afterFirst.epoch()), uint256(currentEpoch), "first EMA must advance epoch");
        assertTrue(
            OraclePack.unwrap(afterFirst) != OraclePack.unwrap(stalePack),
            "stagnant input still produces a distinct pack (epoch advanced, etc.)"
        );

        OraclePack afterSecond = pipeline.runEMA(afterFirst, DEFAULT_PERIODS, DEFAULT_CLAMP);
        assertEq(
            OraclePack.unwrap(afterSecond),
            OraclePack.unwrap(afterFirst),
            "same-epoch re-entry must be bit-exact no-op"
        );

        GrowthObservation old = pipeline.oldest();
        GrowthObservation lat = pipeline.latest();
        assertEq(
            growthToTick(lat.cumulativeGrowth(), old.cumulativeGrowth()),
            int24(0),
            "stagnant pool growth tick must be 0"
        );
    }

    function test__IntegrationSecurityEdge__I2_EMAPassesLatestAsCurrentNotAnchor() public onlyForked {
        pipeline.recordSynthetic(1000, 0, 1e30);
        pipeline.recordSynthetic(1001, 12, 5e30);

        uint24 currentEpoch = uint24((block.timestamp >> 6) & 0xFFFFFF);
        OraclePack stalePack = OraclePackLibrary.storeOraclePack(
            uint256(currentEpoch - 1), 0, 0, int24(0), uint96(0), int24(0), 0
        );

        OraclePack updated = pipeline.runEMA(stalePack, DEFAULT_PERIODS, int24(100));

        int24 storedTick = updated.lastTick();
        assertGt(
            storedTick,
            int24(0),
            "EMA must pass latest.growth as current (positive stored tick); negative indicates inverted arg order"
        );
    }

    function test__IntegrationSecurityEdge__D4_DescendingGrowthCurrentlyWrapsOrShouldRevert() public onlyForked {
        pipeline.recordSynthetic(1000, 0, 5e30);

        try pipeline.recordSynthetic(1001, 12, 1e30) {
            assertEq(pipeline.count(), 2, "both obs recorded despite non-monotonic growth");
            GrowthObservation old = pipeline.oldest();
            GrowthObservation lat = pipeline.latest();
            uint208 wrappedDelta = old.growthDelta(lat);
            assertGt(
                uint256(wrappedDelta),
                uint256(1) << 207,
                "descending growth wraps to near 2^208 (current silent-wrap behavior)"
            );
        } catch {
            assertEq(pipeline.count(), 1, "non-monotonic growth correctly rejected by record()");
        }
    }
}
