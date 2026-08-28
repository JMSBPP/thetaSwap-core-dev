// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {TickRange} from "typed-uniswap-v4/types/TickRangeMod.sol";
import {IAccumulatorSource} from "@range-accrual-note/interfaces/IAccumulatorSource.sol";

/// @title AngstromAccumulatorSource
/// @notice Read-only adapter that reads Angstrom's GrowthOutsideUpdater storage
///         and V4 PoolManager slot0 via `extsload` staticcalls.
/// @dev All storage reads use extsload (selector 0x1e2eaeaf) — no raw sload.
///      Accumulator arithmetic is unchecked (wrapping) to match V3/V4 convention.
contract AngstromAccumulatorSource is IAccumulatorSource {
    // ── Errors ──────────────────────────────────────────────────────

    error ExtsloadFailed();

    // ── Constants ───────────────────────────────────────────────────

    /// @dev Angstrom `poolRewards` mapping is at storage slot 7.
    uint256 private constant POOL_REWARDS_SLOT = 7;

    /// @dev 2^24 — offset from struct base to globalGrowth within poolRewards.
    uint256 private constant REWARD_GROWTH_SIZE = 16777216;

    /// @dev V4 PoolManager pools mapping is at storage slot 6.
    uint256 private constant POOLS_SLOT = 6;

    // ── Immutables ──────────────────────────────────────────────────

    /// @notice Angstrom hook contract address (exposes extsload).
    address public immutable angstrom;

    /// @notice Uniswap V4 PoolManager address (exposes extsload).
    address public immutable poolManager;

    /// @notice Epoch length in blocks.
    uint64 public immutable EPOCH_LENGTH;

    constructor(address angstromHook_, address poolManager_, uint64 epochLengthBlocks_) {
        angstrom = angstromHook_;
        poolManager = poolManager_;
        EPOCH_LENGTH = epochLengthBlocks_;
    }

    // ── Internal helpers ────────────────────────────────────────────

    /// @dev Reads a single storage slot from Angstrom via extsload(uint256).
    ///      Selector: 0x7cf98081
    function _extsloadAngstrom(uint256 slot) internal view returns (uint256 value) {
        address target = angstrom;
        assembly ("memory-safe") {
            mstore(0x00, 0x7cf9808100000000000000000000000000000000000000000000000000000000)
            mstore(0x04, slot)
            if iszero(staticcall(gas(), target, 0x00, 0x24, 0x00, 0x20)) {
                // ExtsloadFailed()
                mstore(0x00, 0xd5ab30f5)
                revert(0x1c, 0x04)
            }
            value := mload(0x00)
        }
    }

    /// @dev Reads a single storage slot from V4 PoolManager via extsload(bytes32).
    ///      Selector: 0x1e2eaeaf
    function _extsloadPoolManager(uint256 slot) internal view returns (uint256 value) {
        address target = poolManager;
        assembly ("memory-safe") {
            mstore(0x00, 0x1e2eaeaf00000000000000000000000000000000000000000000000000000000)
            mstore(0x04, slot)
            if iszero(staticcall(gas(), target, 0x00, 0x24, 0x00, 0x20)) {
                // ExtsloadFailed()
                mstore(0x00, 0xd5ab30f5)
                revert(0x1c, 0x04)
            }
            value := mload(0x00)
        }
    }

    /// @dev Computes the base storage slot for a pool's reward struct in Angstrom.
    ///      struct_base = keccak256(abi.encode(PoolId.unwrap(poolId), POOL_REWARDS_SLOT))
    function _structBase(PoolId poolId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encode(PoolId.unwrap(poolId), POOL_REWARDS_SLOT)));
    }

    /// @dev Reads the current tick from V4 PoolManager slot0 for the given pool.
    ///      Pool state slot = keccak256(abi.encode(PoolId.unwrap(poolId), POOLS_SLOT))
    ///      Tick is at bits [183:160] of slot0 (int24, sign-extended).
    function _currentTick(PoolId poolId) internal view returns (int24 tick) {
        uint256 poolStateSlot = uint256(keccak256(abi.encode(PoolId.unwrap(poolId), POOLS_SLOT)));
        uint256 slot0 = _extsloadPoolManager( poolStateSlot);
        // Extract bits 160..183 as int24
        tick = int24(int256(slot0) >> 160);
    }

    // ── IAccumulatorSource ──────────────────────────────────────────

    /// @inheritdoc IAccumulatorSource
    function growthInside(PoolId poolId, TickRange range) external view returns (uint256) {
        int24 tickLower = range.lowerTick();
        int24 tickUpper = range.upperTick();
        int24 tick = _currentTick(poolId);

        uint256 base = _structBase(poolId);

        // rewardGrowthOutside[t] = struct_base + uint256(uint24(t))
        uint256 outsideBelow = _extsloadAngstrom( base + uint256(uint24(tickLower)));
        uint256 outsideAbove = _extsloadAngstrom( base + uint256(uint24(tickUpper)));

        unchecked {
            if (tick < tickLower) {
                return outsideBelow - outsideAbove;
            } else if (tick >= tickUpper) {
                return outsideAbove - outsideBelow;
            } else {
                // currentTick in [tickLower, tickUpper)
                uint256 global = _extsloadAngstrom( base + REWARD_GROWTH_SIZE);
                return global - outsideBelow - outsideAbove;
            }
        }
    }

    /// @inheritdoc IAccumulatorSource
    function globalGrowth(PoolId poolId) external view returns (uint256) {
        uint256 base = _structBase(poolId);
        return _extsloadAngstrom( base + REWARD_GROWTH_SIZE);
    }

    /// @inheritdoc IAccumulatorSource
    function epochOf(uint64 blockNumber) external view returns (uint40) {
        return uint40(blockNumber / EPOCH_LENGTH);
    }

    /// @inheritdoc IAccumulatorSource
    function epochLength() external view returns (uint64) {
        return EPOCH_LENGTH;
    }
}
