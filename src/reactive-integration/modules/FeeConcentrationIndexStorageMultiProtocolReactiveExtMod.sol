// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ── PSEUDO-CODE: Multi-protocol reactive FCI storage extensions ──
// TODO(refactor): uncomment when REACTIVE_FLAG hookData dispatch is implemented
//
// import {
//     FeeConcentrationIndexStorage,
//     registerPosition,
//     incrementOverlappingRanges
// } from "../../fee-concentration-index/modules/FeeConcentrationIndexStorageMod.sol";
//
// import "../libraries/ProtocolDispatcher.sol";
//
// function registerPosition(
//     bytes calldata hookData,
//     PoolId poolId,
//     TickRange tr,
//     bytes32 positionKey,
//     PositionConfig memory positionConfig,
//     uint128 liquidity
// ) pure {
//     if (isUniswapV3Reactive(hookData)){
//         FeeConcentrationIndexStorage storage reactive$ = reactiveFciStorage();
//         registerPosition(
//             reactive$,
//             poolId,
//             posKey,
//             positionConfig.tickLower,
//             positionConfig.tickUpper,
//             liquidity
//         );
//     }
// }
//
// function incrementPos(bytes calldata hookData, PoolId poolId) pure {
//     if (isUniswapV3Reactive(hookData)){
//         FeeConcentrationIndexStorage storage reactive$ = reactiveFciStorage();
//         incrementPos(reactive$, poolId);
//     }
// }
// ── END PSEUDO-CODE ──
