// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {FixedMarketPrice} from "./FixedMarketPrice.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SqrtPriceX96} from "../../types/SqrtPriceX96.sol";

function poolId(FixedMarketPrice memory fmp) pure returns (PoolId) {
    return fmp.referenceMarket;
}

function lastPrice(FixedMarketPrice memory fmp) pure returns (SqrtPriceX96) {
    return fmp.lastPrice;
}
