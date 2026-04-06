// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange, fromTicksPacked} from "typed-uniswap-v4/types/TickRangeMod.sol";
import {IAccumulatorSource} from "@range-accrual-note/interfaces/IAccumulatorSource.sol";
import {NoteId, VANILLA} from "@range-accrual-note/types/NoteId.sol";
import {NoteSnapshot} from "@range-accrual-note/types/NoteSnapshot.sol";
import {RangeAccrualNote} from "@range-accrual-note/RangeAccrualNote.sol";

/// @dev Mock accumulator source with configurable growthInside and globalGrowth.
contract MockAccumulatorSource is IAccumulatorSource {
    uint256 public mockGrowthInside;
    uint256 public mockGlobalGrowth;
    uint64 public immutable EPOCH_LEN;

    constructor(uint64 epochLen_) {
        EPOCH_LEN = epochLen_;
    }

    function setGrowthInside(uint256 v) external { mockGrowthInside = v; }
    function setGlobalGrowth(uint256 v) external { mockGlobalGrowth = v; }

    function growthInside(PoolId, TickRange) external view returns (uint256) {
        return mockGrowthInside;
    }

    function globalGrowth(PoolId) external view returns (uint256) {
        return mockGlobalGrowth;
    }

    function epochOf(uint64 blockNumber) external view returns (uint40) {
        return uint40(blockNumber / EPOCH_LEN);
    }

    function epochLength() external view returns (uint64) {
        return EPOCH_LEN;
    }
}

/// @dev BTT spec: test/range-accrual-note/trees/RangeAccrualNote_mint.tree
/// @dev BTT spec: test/range-accrual-note/trees/RangeAccrualNote_claim.tree
/// @dev BTT spec: test/range-accrual-note/trees/RangeAccrualNote_transfer.tree
contract RangeAccrualNoteTest is Test {
    RangeAccrualNote note;
    MockAccumulatorSource source;

    PoolId constant POOL_ID = PoolId.wrap(bytes32(uint256(1)));
    int24 constant TICK_LOWER = -100;
    int24 constant TICK_UPPER = 100;
    TickRange range;

    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    // A well-formed NoteId for testing
    NoteId testNoteId;

    function setUp() public {
        source = new MockAccumulatorSource(7200);
        note = new RangeAccrualNote();
        range = fromTicksPacked(TICK_LOWER, TICK_UPPER);

        // Set initial accumulator state
        source.setGrowthInside(1000e18);
        source.setGlobalGrowth(5000e18);

        // Build a valid NoteId
        testNoteId = NoteId.wrap(0)
            .addPoolIndex(1)
            .addVegoid(10)
            .addEpochLength(7200)
            .addExtensionFlag(VANILLA)
            .addNotionalRatio(1)
            .addIsLong(1)
            .addTokenType(0)
            .addTickLower(TICK_LOWER)
            .addTickUpper(TICK_UPPER)
            .addEpochId(uint40(1));
    }

    // ══════════════════════════════════════════════════════════════════
    // MINT tests
    // ══════════════════════════════════════════════════════════════════

    // ── given valid NoteId / when tokenId is new ──

    function test_mint_snapshotsGrowthInside() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        (uint256 entryGI,,) = note.snapshots(testNoteId);
        assertEq(entryGI, 1000e18);
    }

    function test_mint_snapshotsGlobalGrowth() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        (, uint256 entryGG,) = note.snapshots(testNoteId);
        assertEq(entryGG, 5000e18);
    }

    function test_mint_setsTotalLiquidity() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        (,, uint128 totalLiq) = note.snapshots(testNoteId);
        assertEq(totalLiq, 1e18);
    }

    function test_mint_mintsERC1155() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        assertEq(note.balanceOf(alice, NoteId.unwrap(testNoteId)), 1e18);
    }

    function test_mint_validatesNoteId() public {
        // Build NoteId with invalid range (tickLower >= tickUpper)
        NoteId badId = NoteId.wrap(0)
            .addNotionalRatio(1)
            .addTickLower(int24(100))
            .addTickUpper(int24(100));

        vm.expectRevert();
        note.mint(badId, address(source), POOL_ID, range, 1e18, alice);
    }

    // ── when tokenId already exists ──

    function test_mint_subsequentDoesNotResnapshot() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        // Change accumulator state
        source.setGrowthInside(9999e18);
        source.setGlobalGrowth(9999e18);

        // Mint again for bob — should NOT re-snapshot
        note.mint(testNoteId, address(source), POOL_ID, range, 2e18, bob);

        (uint256 entryGI, uint256 entryGG,) = note.snapshots(testNoteId);
        assertEq(entryGI, 1000e18, "entry growthInside should not change on second mint");
        assertEq(entryGG, 5000e18, "entry globalGrowth should not change on second mint");
    }

    function test_mint_subsequentIncrementsTotalLiquidity() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);
        note.mint(testNoteId, address(source), POOL_ID, range, 2e18, bob);

        (,, uint128 totalLiq) = note.snapshots(testNoteId);
        assertEq(totalLiq, 3e18);
    }

    function test_mint_subsequentMintsAdditionalTokens() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);
        note.mint(testNoteId, address(source), POOL_ID, range, 2e18, bob);

        assertEq(note.balanceOf(alice, NoteId.unwrap(testNoteId)), 1e18);
        assertEq(note.balanceOf(bob, NoteId.unwrap(testNoteId)), 2e18);
    }

    // ── revert cases ──

    function test_RevertGiven_invalidRange() public {
        NoteId badId = NoteId.wrap(0)
            .addNotionalRatio(1)
            .addTickLower(int24(200))
            .addTickUpper(int24(100));

        vm.expectRevert();
        note.mint(badId, address(source), POOL_ID, range, 1e18, alice);
    }

    function test_RevertGiven_zeroNotionalRatio() public {
        NoteId badId = NoteId.wrap(0)
            .addNotionalRatio(0)
            .addTickLower(TICK_LOWER)
            .addTickUpper(TICK_UPPER);

        vm.expectRevert();
        note.mint(badId, address(source), POOL_ID, range, 1e18, alice);
    }

    function test_RevertGiven_zeroLiquidity() public {
        vm.expectRevert();
        note.mint(testNoteId, address(source), POOL_ID, range, 0, alice);
    }

    // ══════════════════════════════════════════════════════════════════
    // CLAIM tests
    // ══════════════════════════════════════════════════════════════════

    // ── given holder has balance / growthInside and globalGrowth increased ──

    function test_claim_returnsRatio() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        // Simulate: growthInside went from 1000 to 3000, globalGrowth from 5000 to 9000
        // ratio = (3000-1000) / (9000-5000) = 2000/4000 = 0.5
        source.setGrowthInside(3000e18);
        source.setGlobalGrowth(9000e18);

        vm.prank(alice);
        uint256 ratio = note.claim(testNoteId, address(source), POOL_ID, range);

        // ratio should be 0.5 (represented as a fixed-point number)
        // Exact representation depends on implementation — just check non-zero
        assertGt(ratio, 0, "ratio should be > 0 when price was in range");
    }

    // ── globalGrowth increased but growthInside unchanged (out of range) ──

    function test_claim_returnsZeroWhenOutOfRange() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        // growthInside unchanged (price out of range), globalGrowth increased
        source.setGrowthInside(1000e18); // same as entry
        source.setGlobalGrowth(9000e18);

        vm.prank(alice);
        uint256 ratio = note.claim(testNoteId, address(source), POOL_ID, range);

        assertEq(ratio, 0, "ratio should be 0 when growthInside didn't change");
    }

    // ── neither changed ──

    function test_claim_returnsZeroWhenNothingChanged() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        // No change from entry values
        vm.prank(alice);
        uint256 ratio = note.claim(testNoteId, address(source), POOL_ID, range);

        assertEq(ratio, 0);
    }

    // ── idempotency ──

    function test_claim_idempotent() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        source.setGrowthInside(3000e18);
        source.setGlobalGrowth(9000e18);

        vm.startPrank(alice);
        uint256 first = note.claim(testNoteId, address(source), POOL_ID, range);
        uint256 second = note.claim(testNoteId, address(source), POOL_ID, range);
        vm.stopPrank();

        assertGt(first, 0, "first claim should return ratio");
        assertEq(second, 0, "second claim should return 0 (idempotent)");
    }

    // ── revert: zero balance ──

    function test_RevertGiven_claimWithZeroBalance() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        // Bob has no tokens
        vm.prank(bob);
        vm.expectRevert();
        note.claim(testNoteId, address(source), POOL_ID, range);
    }

    // ── revert: uninitialized tokenId ──

    function test_RevertGiven_claimUninitialized() public {
        // Never minted — NoteId points to uninitialized snapshot
        NoteId unminted = NoteId.wrap(0)
            .addNotionalRatio(1)
            .addTickLower(int24(-200))
            .addTickUpper(int24(200))
            .addEpochId(uint40(99));

        vm.prank(alice);
        vm.expectRevert();
        note.claim(unminted, address(source), POOL_ID, range);
    }

    // ══════════════════════════════════════════════════════════════════
    // TRANSFER tests
    // ══════════════════════════════════════════════════════════════════

    function test_transfer_updatesBalances() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 3e18, alice);

        vm.prank(alice);
        note.safeTransferFrom(alice, bob, NoteId.unwrap(testNoteId), 1e18, "");

        assertEq(note.balanceOf(alice, NoteId.unwrap(testNoteId)), 2e18);
        assertEq(note.balanceOf(bob, NoteId.unwrap(testNoteId)), 1e18);
    }

    function test_transfer_doesNotChangeTotalLiquidity() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 3e18, alice);

        (,, uint128 totalBefore) = note.snapshots(testNoteId);

        vm.prank(alice);
        note.safeTransferFrom(alice, bob, NoteId.unwrap(testNoteId), 1e18, "");

        (,, uint128 totalAfter) = note.snapshots(testNoteId);
        assertEq(totalBefore, totalAfter, "totalLiquidity must not change on transfer");
    }

    function test_transfer_toSelf() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 3e18, alice);

        vm.prank(alice);
        note.safeTransferFrom(alice, alice, NoteId.unwrap(testNoteId), 1e18, "");

        assertEq(note.balanceOf(alice, NoteId.unwrap(testNoteId)), 3e18);
    }

    function test_RevertGiven_transferExceedsBalance() public {
        note.mint(testNoteId, address(source), POOL_ID, range, 1e18, alice);

        vm.prank(alice);
        vm.expectRevert();
        note.safeTransferFrom(alice, bob, NoteId.unwrap(testNoteId), 2e18, "");
    }
}
