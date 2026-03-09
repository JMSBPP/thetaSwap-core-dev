// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";

// Read feeGrowthInside0X128 from a V3 pool's on-chain state.
// Same-chain staticcalls — the adapter and pool are both on Sepolia.
// Mirrors the V3 pool's internal _getFeeGrowthInside() logic.

function v3FeeGrowthInside0(
    IUniswapV3Pool pool,
    int24 tickLower,
    int24 tickUpper
) view returns (uint256 feeGrowthInside0X128) {
    (,, uint256 feeGrowthOutsideLower0,,,,, ) = pool.ticks(tickLower);
    (,, uint256 feeGrowthOutsideUpper0,,,,, ) = pool.ticks(tickUpper);
    uint256 feeGrowthGlobal0 = pool.feeGrowthGlobal0X128();
    (, int24 currentTick,,,,,) = pool.slot0();

    unchecked {
        uint256 feeGrowthBelow0;
        if (currentTick >= tickLower) {
            feeGrowthBelow0 = feeGrowthOutsideLower0;
        } else {
            feeGrowthBelow0 = feeGrowthGlobal0 - feeGrowthOutsideLower0;
        }

        uint256 feeGrowthAbove0;
        if (currentTick < tickUpper) {
            feeGrowthAbove0 = feeGrowthOutsideUpper0;
        } else {
            feeGrowthAbove0 = feeGrowthGlobal0 - feeGrowthOutsideUpper0;
        }

        feeGrowthInside0X128 = feeGrowthGlobal0 - feeGrowthBelow0 - feeGrowthAbove0;
    }
}

// Read a position's stored feeGrowthInside0LastX128 from V3 pool.
// V3 updates this during burn() BEFORE de-initializing ticks,
// so it equals current feeGrowthInside even after full position removal.
function v3PositionFeeGrowthLast0(
    IUniswapV3Pool pool,
    address owner,
    int24 tickLower,
    int24 tickUpper
) view returns (uint256 feeGrowthInside0LastX128) {
    bytes32 posKey = keccak256(abi.encodePacked(owner, tickLower, tickUpper));
    (, feeGrowthInside0LastX128,,,) = pool.positions(posKey);
}
