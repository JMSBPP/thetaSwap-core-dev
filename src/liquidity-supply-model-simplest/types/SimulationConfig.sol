// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Capital} from "../../types/Capital.sol";

struct SimulationConfig {
    Capital initialCapital;
    uint256 numSwaps;
    uint256 swapAmount;
    uint160 sqrtPriceX96;
}
