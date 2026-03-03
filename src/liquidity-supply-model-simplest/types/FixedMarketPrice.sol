// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {SqrtPriceX96} from "../../types/SqrtPriceX96.sol";

struct FixedMarketPrice {
    SqrtPriceX96 lastPrice;
    PoolId referenceMarket;
}
