// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange, fromTicksPacked} from "typed-uniswap-v4/types/TickRangeMod.sol";
import {AngstromAccumulatorSource} from "@range-accrual-note/adapters/AngstromAccumulatorSource.sol";

/// @dev BTT spec: test/range-accrual-note/trees/AngstromAccumulatorSource_growthInside.tree
contract AngstromAccumulatorSourceForkTest is Test {
    // ── Mainnet addresses ───────────────────────────────────────────
    address constant ANGSTROM_HOOK = 0x0000000aa232009084Bd71A5797d089AA4Edfad4;
    address constant POOL_MANAGER  = 0x000000000004444c5dc75cB358380D2e3dE08A90;

    // ── WETH/USDC pool ──────────────────────────────────────────────
    PoolId constant POOL_ID = PoolId.wrap(0xe500210c7ea6bfd9f69dce044b09ef384ec2b34832f132baec3b418208e3a657);
    int24  constant TICK_SPACING = 10;

    // ── Storage layout (Exercise B, verified on mainnet) ────────────
    uint256 constant POOL_REWARDS_SLOT  = 7;
    uint256 constant REWARD_GROWTH_SIZE = 16777216; // 2^24
    uint256 constant POOLS_SLOT         = 6;

    // ── Epoch config ────────────────────────────────────────────────
    uint64 constant EPOCH_LENGTH_BLOCKS = 7200;

    // ── Derived ─────────────────────────────────────────────────────
    AngstromAccumulatorSource adapter;
    uint256 structBase;
    uint256 poolStateSlot;

    function setUp() public {
        uint256 mainnetFork = vm.createFork(
            vm.envOr("ETH_RPC_URL", string("https://eth.llamarpc.com"))
        );
        vm.selectFork(mainnetFork);

        adapter = new AngstromAccumulatorSource(ANGSTROM_HOOK, POOL_MANAGER, EPOCH_LENGTH_BLOCKS);

        structBase    = uint256(keccak256(abi.encode(PoolId.unwrap(POOL_ID), POOL_REWARDS_SLOT)));
        poolStateSlot = uint256(keccak256(abi.encode(PoolId.unwrap(POOL_ID), POOLS_SLOT)));
    }

    /// @dev Read current tick from PoolManager slot0 via vm.load (cheatcode path).
    function _readCurrentTick() internal view returns (int24) {
        uint256 slot0 = uint256(vm.load(POOL_MANAGER, bytes32(poolStateSlot)));
        return int24(int256(slot0) >> 160);
    }

    // ══════════════════════════════════════════════════════════════════
    // Test 1: globalGrowth is non-zero on a live pool
    // ══════════════════════════════════════════════════════════════════

    function test_globalGrowth_isNonZero() public {
        uint256 global = adapter.globalGrowth(POOL_ID);
        emit log_named_uint("globalGrowth", global);
        assertGt(global, 0, "globalGrowth should be > 0 on a live Angstrom pool");
    }

    // ══════════════════════════════════════════════════════════════════
    // Test 2: growthInside > 0 for an active range around current tick
    // ══════════════════════════════════════════════════════════════════

    function test_growthInside_forActiveRange() public {
        int24 currentTick = _readCurrentTick();

        // Build a range around current tick, aligned to tick spacing
        int24 lower = ((currentTick - 500) / TICK_SPACING) * TICK_SPACING;
        int24 upper = ((currentTick + 500) / TICK_SPACING) * TICK_SPACING + TICK_SPACING;
        TickRange range = fromTicksPacked(lower, upper);

        uint256 inside = adapter.growthInside(POOL_ID, range);
        uint256 global = adapter.globalGrowth(POOL_ID);

        emit log_named_int("currentTick", int256(currentTick));
        emit log_named_int("rangeLower", int256(lower));
        emit log_named_int("rangeUpper", int256(upper));
        emit log_named_uint("growthInside", inside);
        emit log_named_uint("globalGrowth", global);

        assertGt(inside, 0, "growthInside should be > 0 for an active range around current tick");
    }

    // ══════════════════════════════════════════════════════════════════
    // Test 3: adapter extsload matches direct vm.load
    // ══════════════════════════════════════════════════════════════════

    function test_conservation_adapterMatchesDirectRead() public {
        // ── globalGrowth cross-validation ──
        uint256 globalViaAdapter = adapter.globalGrowth(POOL_ID);
        uint256 globalViaVmLoad  = uint256(vm.load(ANGSTROM_HOOK, bytes32(structBase + REWARD_GROWTH_SIZE)));

        emit log_named_uint("globalViaAdapter", globalViaAdapter);
        emit log_named_uint("globalViaVmLoad",  globalViaVmLoad);
        assertEq(globalViaAdapter, globalViaVmLoad, "adapter globalGrowth must match direct storage read");

        // ── outsideBelow / outsideAbove for specific ticks ──
        int24 currentTick = _readCurrentTick();
        int24 lower = ((currentTick - 500) / TICK_SPACING) * TICK_SPACING;
        int24 upper = ((currentTick + 500) / TICK_SPACING) * TICK_SPACING + TICK_SPACING;

        uint256 outsideBelowDirect = uint256(vm.load(ANGSTROM_HOOK, bytes32(structBase + uint256(uint24(lower)))));
        uint256 outsideAboveDirect = uint256(vm.load(ANGSTROM_HOOK, bytes32(structBase + uint256(uint24(upper)))));

        // Read growthInside via adapter
        uint256 insideViaAdapter = adapter.growthInside(POOL_ID, fromTicksPacked(lower, upper));

        // current tick is in [lower, upper) by construction, so:
        // insideViaAdapter == globalGrowth - outsideBelow - outsideAbove
        uint256 insideManual;
        unchecked {
            insideManual = globalViaVmLoad - outsideBelowDirect - outsideAboveDirect;
        }

        emit log_named_uint("outsideBelowDirect", outsideBelowDirect);
        emit log_named_uint("outsideAboveDirect", outsideAboveDirect);
        emit log_named_uint("insideViaAdapter",   insideViaAdapter);
        emit log_named_uint("insideManual",        insideManual);

        assertEq(insideViaAdapter, insideManual, "adapter growthInside must match manual computation");
    }

    // ══════════════════════════════════════════════════════════════════
    // Test 4: conservation — inside + outsideBelow + outsideAbove == global
    // ══════════════════════════════════════════════════════════════════

    function test_growthInside_conservation_inRange() public {
        int24 currentTick = _readCurrentTick();
        int24 lower = ((currentTick - 500) / TICK_SPACING) * TICK_SPACING;
        int24 upper = ((currentTick + 500) / TICK_SPACING) * TICK_SPACING + TICK_SPACING;

        uint256 outsideBelow = uint256(vm.load(ANGSTROM_HOOK, bytes32(structBase + uint256(uint24(lower)))));
        uint256 outsideAbove = uint256(vm.load(ANGSTROM_HOOK, bytes32(structBase + uint256(uint24(upper)))));
        uint256 global       = uint256(vm.load(ANGSTROM_HOOK, bytes32(structBase + REWARD_GROWTH_SIZE)));
        uint256 inside       = adapter.growthInside(POOL_ID, fromTicksPacked(lower, upper));

        emit log_named_uint("outsideBelow", outsideBelow);
        emit log_named_uint("outsideAbove", outsideAbove);
        emit log_named_uint("globalGrowth", global);
        emit log_named_uint("growthInside", inside);

        // Conservation: inside + outsideBelow + outsideAbove == globalGrowth
        uint256 sum;
        unchecked {
            sum = inside + outsideBelow + outsideAbove;
        }
        assertEq(sum, global, "conservation: inside + outsideBelow + outsideAbove must equal globalGrowth");
    }

    // ══════════════════════════════════════════════════════════════════
    // Test 5: epochOf returns reasonable value for current block
    // ══════════════════════════════════════════════════════════════════

    function test_epochOf_currentBlock() public {
        uint40 epoch = adapter.epochOf(uint64(block.number));
        uint40 expected = uint40(block.number / EPOCH_LENGTH_BLOCKS);

        emit log_named_uint("block.number", block.number);
        emit log_named_uint("epoch",        uint256(epoch));
        emit log_named_uint("expected",     uint256(expected));

        assertEq(epoch, expected, "epochOf must equal block.number / epochLength");
        assertGt(epoch, 0, "epoch should be > 0 on mainnet");
    }
}
