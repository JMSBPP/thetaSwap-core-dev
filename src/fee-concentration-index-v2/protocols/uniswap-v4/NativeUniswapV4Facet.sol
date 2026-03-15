// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "v4-core/src/types/PoolId.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {TickRange} from "typed-uniswap-v4/types/TickRangeMod.sol";
import {SwapCount} from "typed-uniswap-v4/types/SwapCountMod.sol";
import {BlockCount} from "typed-uniswap-v4/types/BlockCountMod.sol";
import {LiquidityPositionSnapshot} from "@fee-concentration-index-v2/types/LiquidityPositionSnapshot.sol";
import {NATIVE_V4} from "@fee-concentration-index-v2/types/FlagsRegistry.sol";
import {fciFacetAdminStorage} from "@fee-concentration-index-v2/modules/FCIFacetAdminStorageMod.sol";

/// @title NativeUniswapV4Facet
/// @dev Protocol facet for Uniswap V4 native hooks.
/// Called via delegatecall from FeeConcentrationIndexV2 for each behavioral function.
/// Contains ONLY behavioral functions — hook orchestration lives in V2.
/// Does NOT inherit IFCIProtocolFacet explicitly (SCOP: no is inheritance).
contract NativeUniswapV4Facet {

    address immutable _self;

    constructor() {
        _self = address(this);
    }

    modifier onlyDelegateCall() {
        require(address(this) != _self, "NativeUniswapV4Facet: direct call");
        require(address(this) == address(fciFacetAdminStorage(NATIVE_V4).fci), "NativeUniswapV4Facet: unauthorized caller");
        _;
    }

    // ── Position key derivation ──

    function positionKey(bytes calldata hookData, address sender, ModifyLiquidityParams calldata params) external view onlyDelegateCall returns (bytes32) {
        // TODO: Position.calculatePositionKey(sender, tickLower, tickUpper, salt)
    }

    // ── Fee growth reads ──

    function latestPositionFeeGrowthInside(bytes calldata hookData, PoolId poolId, bytes32 posKey) external view onlyDelegateCall returns (uint128 posLiquidity, uint256 feeGrowthLast) {
        // TODO: StateLibrary.getPositionInfo(poolManager, poolId, posKey)
    }

    function poolRangeFeeGrowthInside(bytes calldata hookData, PoolId poolId, int24 currentTick_, TickRange tickRange) external view onlyDelegateCall returns (uint256) {
        // TODO: StateLibrary.getFeeGrowthInside(poolManager, poolId, tickLower, tickUpper)
    }

    // ── Position registration ──

    function addPositionInRange(bytes calldata hookData, bytes32 posKey, LiquidityPositionSnapshot calldata snapshot) external onlyDelegateCall {
        // TODO: register position in V2 storage at NATIVE_V4 slot
    }

    function removePositionInRange(bytes calldata hookData, bytes32 posKey, LiquidityPositionSnapshot calldata snapshot) external onlyDelegateCall returns (SwapCount swapLifetime, BlockCount blockLifetime, uint128 totalRangeLiq) {
        // TODO: deregister position from V2 storage at NATIVE_V4 slot
    }

    // ── Tick ──

    function currentTick(bytes calldata hookData) external view onlyDelegateCall returns (int24) {
        // TODO: StateLibrary.getSlot0(poolManager, poolId)
    }

    // ── Fee growth baseline ──

    function setFeeGrowthBaseline(bytes calldata hookData, PoolId poolId, bytes32 posKey, uint256 feeGrowth) external onlyDelegateCall {
        // TODO: write to V2 storage
    }

    function getFeeGrowthBaseline(bytes calldata hookData, PoolId poolId, bytes32 posKey) external view onlyDelegateCall returns (uint256) {
        // TODO: read from V2 storage
    }

    function deleteFeeGrowthBaseline(bytes calldata hookData, PoolId poolId, bytes32 posKey) external onlyDelegateCall {
        // TODO: delete from V2 storage
    }

    // ── Position count ──

    function incrementPosCount(bytes calldata hookData, PoolId poolId) external onlyDelegateCall {
        // TODO: increment in V2 storage
    }

    function decrementPosCount(bytes calldata hookData, PoolId poolId) external onlyDelegateCall {
        // TODO: decrement in V2 storage
    }

    // ── Transient storage ──

    function tstoreTick(bytes calldata hookData, int24 tick) external onlyDelegateCall {
        // TODO: transient store via FCIProtocolFacetStorageMod
    }

    function tloadTick(bytes calldata hookData) external view onlyDelegateCall returns (int24 tick) {
        // TODO: transient load via FCIProtocolFacetStorageMod
    }

    function tstoreRemovalData(bytes calldata hookData, uint256 feeLast, uint128 posLiquidity, uint256 rangeFeeGrowth) external onlyDelegateCall {
        // TODO: transient store via FCIProtocolFacetStorageMod
    }

    function tloadRemovalData(bytes calldata hookData) external view onlyDelegateCall returns (uint256 feeLast, uint128 posLiquidity, uint256 rangeFeeGrowth) {
        // TODO: transient load via FCIProtocolFacetStorageMod
    }

    // ── Overlapping ranges ──

    function incrementOverlappingRanges(bytes calldata hookData, PoolId poolId, int24 tickMin, int24 tickMax) external onlyDelegateCall {
        // TODO: iterate V2 registry ranges, check intersects, increment swap count
    }

    // ── FCI state accumulation ──

    function addStateTerm(bytes calldata hookData, PoolId poolId, BlockCount blockLifetime, uint256 xSquaredQ128) external onlyDelegateCall {
        // TODO: accumulate in V2 storage
    }

    function addEpochTerm(bytes calldata hookData, PoolId poolId, BlockCount blockLifetime, uint256 xSquaredQ128) external onlyDelegateCall {
        // TODO: accumulate in epoch storage
    }
}
