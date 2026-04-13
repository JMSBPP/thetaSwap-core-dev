// SPDX-License-Identifier: MIT
pragma solidity >=0.8.26;

import {IAngstromAuth} from "core/src/interfaces/IAngstromAuth.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolConfigStore} from "core/src/libraries/PoolConfigStore.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/// @title IAngstromAccumulatorConsumer
/// @notice Read-only Angstrom client. Surfaces accumulator values, block metadata,
///         and pool configuration via extsload. Does NOT write any state.
interface IAngstromAccumulatorConsumer {
    // ── Accumulator reads ──

    /// @notice Returns the cumulative global reward growth for a pool.
    function globalGrowth(PoolId poolId) external view returns (uint256 _globalGrowth);

    /// @notice Returns the cumulative reward growth inside a tick range.
    function growthInside(PoolId poolId, int24 tickLower, int24 tickUpper)
        external
        view
        returns (uint256);

    // ── Metadata reads ──

    /// @notice Returns the block number of the most recent Angstrom bundle execution.
    function lastBlockUpdated() external view returns (uint64);

    /// @notice Returns the SSTORE2 address of Angstrom's current PoolConfigStore.
    function configStore() external view returns (PoolConfigStore);

    /// @notice Returns the Uniswap V4 PoolManager this consumer queries.
    function poolManager() external view returns (IPoolManager);

    /// @notice Returns the Angstrom contract this consumer reads via extsload.
    function angstrom() external view returns (IAngstromAuth);

    // ── Pool configuration reads ──

    /// @notice Returns whether at least one Angstrom pool exists for the given token pair.
    /// @param token0 The lower-address token. Must be less than token1.
    /// @param token1 The higher-address token.
    function poolExists(address token0, address token1) external view returns (bool);

    /// @notice Returns the tick spacing and bundle fee for a specific pool config entry.
    /// @dev Reverts with NoEntry if the index has no matching entry for the token pair.
    /// @param token0 The lower-address token (caller must sort).
    /// @param token1 The higher-address token.
    /// @param index The config entry index to read.
    function getPoolConfig(address token0, address token1, uint256 index)
        external
        view
        returns (int24 tickSpacing, uint24 bundleFee);

    function getPoolId(IERC20 token0, IERC20 token1) external view returns(PoolId poolId);
}
