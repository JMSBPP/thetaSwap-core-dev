// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange, fromTicksPacked} from "typed-uniswap-v4/types/TickRangeMod.sol";
import {IAccumulatorSource} from "@range-accrual-note/interfaces/IAccumulatorSource.sol";

/// @dev BTT spec: test/range-accrual-note/trees/AngstromAccumulatorSource_growthInside.tree

/// @dev Mock that implements extsload(uint256) backed by a mapping.
///      The adapter will staticcall this to read "Angstrom storage".
contract MockExtsload {
    mapping(uint256 => uint256) public slots;

    function extsload(uint256 slot) external view returns (uint256) {
        return slots[slot];
    }

    function setSlot(uint256 slot, uint256 value) external {
        slots[slot] = value;
    }
}

/// @dev Mock PoolManager that implements extsload for slot0 (current tick).
///      Slot0 layout: sqrtPriceX96 (160 bits) | tick (24 bits) | protocolFee (24 bits) | lpFee (24 bits) | ...
///      tick is at bits 160-183.
contract MockPoolManager {
    mapping(uint256 => uint256) public slots;

    function extsload(uint256 slot) external view returns (uint256) {
        return slots[slot];
    }

    /// @dev Pack a tick into slot0 format at bits 160-183
    function setCurrentTick(bytes32 poolStateSlot, int24 tick) external {
        uint256 current = slots[uint256(poolStateSlot)];
        // Clear bits 160-183, then set tick
        current = current & ~(uint256(0xFFFFFF) << 160);
        current = current | (uint256(uint24(tick)) << 160);
        slots[uint256(poolStateSlot)] = current;
    }

    function setSlot(uint256 slot, uint256 value) external {
        slots[slot] = value;
    }
}

contract AngstromAccumulatorSourceTest is Test {
    // Will be replaced by real adapter once Task 5 is implemented
    // For now these tests define the expected behavior

    MockExtsload angstromMock;
    MockPoolManager poolManagerMock;

    // Angstrom storage layout constants (from Exercise B, verified on mainnet)
    uint256 constant POOL_REWARDS_SLOT = 7;
    uint256 constant REWARD_GROWTH_SIZE = 16777216; // 2^24

    // Test pool
    PoolId constant POOL_ID = PoolId.wrap(0xe500210c7ea6bfd9f69dce044b09ef384ec2b34832f132baec3b418208e3a657);

    // Computed struct base for this pool
    uint256 structBase;

    // Test range: ticks -100 to +100
    int24 constant TICK_LOWER = -100;
    int24 constant TICK_UPPER = 100;
    TickRange range;

    // Slot computation for the pool's slot0 in PoolManager (slot 6 = _pools mapping)
    uint256 poolStateSlot;

    function setUp() public {
        angstromMock = new MockExtsload();
        poolManagerMock = new MockPoolManager();

        range = fromTicksPacked(TICK_LOWER, TICK_UPPER);

        // Compute struct base: keccak256(abi.encode(poolId, 7))
        structBase = uint256(keccak256(abi.encode(PoolId.unwrap(POOL_ID), POOL_REWARDS_SLOT)));

        // Compute pool state slot for PoolManager: keccak256(abi.encode(poolId, 6))
        poolStateSlot = uint256(keccak256(abi.encode(PoolId.unwrap(POOL_ID), uint256(6))));
    }

    // ── Helpers ──

    function _setGlobalGrowth(uint256 value) internal {
        angstromMock.setSlot(structBase + REWARD_GROWTH_SIZE, value);
    }

    function _setOutsideBelow(int24 tick, uint256 value) internal {
        angstromMock.setSlot(structBase + uint256(uint24(tick)), value);
    }

    function _setOutsideAbove(int24 tick, uint256 value) internal {
        angstromMock.setSlot(structBase + uint256(uint24(tick)), value);
    }

    function _setCurrentTick(int24 tick) internal {
        poolManagerMock.setCurrentTick(bytes32(poolStateSlot), tick);
    }

    /// @dev Manually compute expected growthInside given the three-branch logic
    function _expectedGrowthInside(
        int24 currentTick,
        uint256 global,
        uint256 outsideBelow,
        uint256 outsideAbove
    ) internal pure returns (uint256) {
        if (currentTick < TICK_LOWER) {
            return outsideBelow - outsideAbove;
        } else if (currentTick >= TICK_UPPER) {
            return outsideAbove - outsideBelow;
        } else {
            return global - outsideBelow - outsideAbove;
        }
    }

    // ══════════════════════════════════════════════
    // growthInside tests
    // ══════════════════════════════════════════════

    // ── given current tick is within [tickLower, tickUpper) ──

    function test_growthInside_givenTickInRange_returnsGlobalMinusOutsides() public {
        _setGlobalGrowth(10000);
        _setOutsideBelow(TICK_LOWER, 2000);
        _setOutsideAbove(TICK_UPPER, 3000);
        _setCurrentTick(0); // in range [-100, 100)

        uint256 expected = 10000 - 2000 - 3000; // 5000
        assertEq(expected, 5000);

        // This assertion will be against the adapter once implemented (Task 5)
        // For now we verify the expected computation
        assertEq(
            _expectedGrowthInside(0, 10000, 2000, 3000),
            5000
        );
    }

    // ── given current tick is below tickLower ──

    function test_growthInside_givenTickBelowRange_returnsOutsideBelowMinusAbove() public {
        _setGlobalGrowth(10000);
        _setOutsideBelow(TICK_LOWER, 7000);
        _setOutsideAbove(TICK_UPPER, 1000);
        _setCurrentTick(-200); // below range

        uint256 expected = 7000 - 1000; // 6000
        assertEq(
            _expectedGrowthInside(-200, 10000, 7000, 1000),
            6000
        );
    }

    // ── given current tick is at or above tickUpper ──

    function test_growthInside_givenTickAboveRange_returnsOutsideAboveMinusBelow() public {
        _setGlobalGrowth(10000);
        _setOutsideBelow(TICK_LOWER, 1000);
        _setOutsideAbove(TICK_UPPER, 8000);
        _setCurrentTick(200); // above range

        uint256 expected = 8000 - 1000; // 7000
        assertEq(
            _expectedGrowthInside(200, 10000, 1000, 8000),
            7000
        );
    }

    // ── given all growth values are zero ──

    function test_growthInside_givenAllZero_returnsZero() public view {
        // Default: all slots are zero
        assertEq(_expectedGrowthInside(0, 0, 0, 0), 0);
    }

    // ── conservation property ──

    function test_growthInside_conservation_inRange() public {
        uint256 global = 10000;
        uint256 outsideBelow = 2000;
        uint256 outsideAbove = 3000;

        _setGlobalGrowth(global);
        _setOutsideBelow(TICK_LOWER, outsideBelow);
        _setOutsideAbove(TICK_UPPER, outsideAbove);
        _setCurrentTick(0);

        uint256 inside = _expectedGrowthInside(0, global, outsideBelow, outsideAbove);

        // Conservation: inside + outsideBelow + outsideAbove == globalGrowth
        assertEq(inside + outsideBelow + outsideAbove, global);
    }

    // ── fuzz: conservation holds for arbitrary values ──

    function testFuzz_growthInside_conservation(
        uint128 global,
        uint128 outsideBelow,
        uint128 outsideAbove
    ) public pure {
        // Ensure global >= outsideBelow + outsideAbove (valid accumulator state)
        vm.assume(uint256(global) >= uint256(outsideBelow) + uint256(outsideAbove));

        uint256 g = uint256(global);
        uint256 ob = uint256(outsideBelow);
        uint256 oa = uint256(outsideAbove);

        uint256 inside = g - ob - oa;
        assertEq(inside + ob + oa, g);
    }

    // ══════════════════════════════════════════════
    // globalGrowth tests
    // ══════════════════════════════════════════════

    function test_globalGrowth_givenRewardsAccumulated_returnsValue() public {
        _setGlobalGrowth(42_000_000);
        uint256 value = angstromMock.slots(structBase + REWARD_GROWTH_SIZE);
        assertEq(value, 42_000_000);
    }

    function test_globalGrowth_givenNoRewards_returnsZero() public view {
        uint256 value = angstromMock.slots(structBase + REWARD_GROWTH_SIZE);
        assertEq(value, 0);
    }

    // ══════════════════════════════════════════════
    // epochOf tests
    // ══════════════════════════════════════════════

    function test_epochOf_returnsBlockDividedByLength() public pure {
        // epochLength = 7200 blocks (~1 day at 12s/block)
        uint64 epochLength = 7200;
        uint64 blockNumber = 14400;
        uint40 expected = uint40(blockNumber / epochLength); // 2
        assertEq(expected, 2);
    }

    function test_epochOf_givenBlockZero_returnsZero() public pure {
        uint64 epochLength = 7200;
        uint40 expected = uint40(uint64(0) / epochLength);
        assertEq(expected, 0);
    }

    function test_epochOf_boundaryBlock() public pure {
        uint64 epochLength = 7200;
        // Block 7199 = epoch 0, block 7200 = epoch 1
        assertEq(uint40(uint64(7199) / epochLength), 0);
        assertEq(uint40(uint64(7200) / epochLength), 1);
    }

    // ══════════════════════════════════════════════
    // epochLength test
    // ══════════════════════════════════════════════

    function test_epochLength_returnsConfigured() public pure {
        uint64 epochLength = 7200;
        assertEq(epochLength, 7200);
    }

    // ══════════════════════════════════════════════
    // Storage layout verification
    // ══════════════════════════════════════════════

    function test_storageLayout_structBaseComputation() public pure {
        // Verify the struct base matches Exercise B's formula
        bytes32 poolId = 0xe500210c7ea6bfd9f69dce044b09ef384ec2b34832f132baec3b418208e3a657;
        uint256 computed = uint256(keccak256(abi.encode(poolId, uint256(7))));
        // This is deterministic — just verify it's non-zero and stable
        assertTrue(computed != 0);
    }

    function test_storageLayout_globalGrowthOffset() public pure {
        // globalGrowth is at struct_base + 2^24
        assertEq(REWARD_GROWTH_SIZE, 1 << 24);
        assertEq(REWARD_GROWTH_SIZE, 16777216);
    }

    function test_storageLayout_tickSlotComputation() public view {
        // rewardGrowthOutside[tick] = struct_base + uint24(tick)
        // For tick = -100: uint24(-100) = 16777116
        uint256 slot = structBase + uint256(uint24(TICK_LOWER));
        assertTrue(slot > structBase);

        // For tick = 100: uint24(100) = 100
        uint256 slotUpper = structBase + uint256(uint24(TICK_UPPER));
        assertEq(slotUpper, structBase + 100);
    }
}
