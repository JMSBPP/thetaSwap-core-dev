// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {SlotDerivation} from "openzeppelin-contracts/utils/SlotDerivation.sol";
import {IAngstromAuth} from "core/src/interfaces/IAngstromAuth.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IUniV4} from "core/src/interfaces/IUniV4.sol";
import {PoolConfigStore, PoolConfigStoreLib} from "core/src/libraries/PoolConfigStore.sol";
import {StoreKey, StoreKeyLib} from "core/src/types/StoreKey.sol";
import {ConfigEntry, ConfigEntryLib} from "core/src/types/ConfigEntry.sol";

contract AngstromAccumulatorConsumer {
    uint256 private constant POOL_REWARDS_SLOT = 7;
    uint256 private constant REWARD_GROWTH_SIZE = 16777216;
    uint256 private constant LAST_BLOCK_CONFIG_STORE_SLOT = 3;
    uint256 private constant LAST_BLOCK_BIT_OFFSET = 0;
    uint256 private constant STORE_BIT_OFFSET = 64;

    IPoolManager immutable UNI_V4;
    IAngstromAuth immutable ANGSTROM;

    using SlotDerivation for bytes32;
    using IUniV4 for IPoolManager;
    using PoolConfigStoreLib for PoolConfigStore;
    using ConfigEntryLib for ConfigEntry;
    using StoreKeyLib for address;

    constructor(IAngstromAuth _angstrom, IPoolManager _poolManager) {
        ANGSTROM = _angstrom;
        UNI_V4 = _poolManager;
    }

    function globalGrowth(PoolId poolId) external view returns (uint256 _globalGrowth) {
        bytes32 base = bytes32(POOL_REWARDS_SLOT).deriveMapping(PoolId.unwrap(poolId));
        _globalGrowth = ANGSTROM.extsload(uint256(base.offset(REWARD_GROWTH_SIZE)));
    }

    function growthInside(PoolId poolId, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256)
    {
        bytes32 base = bytes32(POOL_REWARDS_SLOT).deriveMapping(PoolId.unwrap(poolId));
        int24 currentTick = UNI_V4.getSlot0(poolId).tick();

        uint256 outsideBelow = ANGSTROM.extsload(uint256(base.offset(uint256(uint24(tickLower)))));
        uint256 outsideAbove = ANGSTROM.extsload(uint256(base.offset(uint256(uint24(tickUpper)))));

        unchecked {
            if (currentTick < tickLower) {
                return outsideBelow - outsideAbove;
            } else if (currentTick >= tickUpper) {
                return outsideAbove - outsideBelow;
            } else {
                uint256 global = ANGSTROM.extsload(uint256(base.offset(REWARD_GROWTH_SIZE)));
                return global - outsideBelow - outsideAbove;
            }
        }
    }

    function lastBlockUpdated() external view returns (uint64) {
        return uint64(ANGSTROM.extsload(LAST_BLOCK_CONFIG_STORE_SLOT) >> LAST_BLOCK_BIT_OFFSET);
    }

    function configStore() public view returns (PoolConfigStore) {
        uint256 value = ANGSTROM.extsload(LAST_BLOCK_CONFIG_STORE_SLOT);
        return PoolConfigStore.wrap(address(uint160(value >> STORE_BIT_OFFSET)));
    }

    function poolManager() external view returns (IPoolManager) {
        return UNI_V4;
    }

    function angstrom() external view returns (IAngstromAuth) {
        return ANGSTROM;
    }

    function poolExists(address token0, address token1) external view returns (bool) {
        if (token0 >= token1) return false;

        StoreKey key = StoreKeyLib.keyFromAssetsUnchecked(token0, token1);
        PoolConfigStore store = configStore();
        if (PoolConfigStore.unwrap(store) == address(0)) return false;

        uint256 total = store.totalEntries();
        for (uint256 i; i < total; ++i) {
            ConfigEntry entry = store.getWithDefaultEmpty(key, i);
            if (!entry.isEmpty()) return true;
        }
        return false;
    }

    function getPoolConfig(address token0, address token1, uint256 index)
        external
        view
        returns (int24 tickSpacing, uint24 bundleFee)
    {
        StoreKey key = StoreKeyLib.keyFromAssetsUnchecked(token0, token1);
        return configStore().get(key, index);
    }
}
