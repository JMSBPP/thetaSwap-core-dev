// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {SimulationConfig} from "../../../src/liquidity-supply-model-simplest/types/SimulationConfig.sol";
import {Capital} from "../../../src/types/Capital.sol";

abstract contract LiquiditySupplyModelSimplestTest is Test {
    address constant TRADER = address(0xBEEF);

    SimulationConfig internal config;

    function setUp() public virtual {
        config = SimulationConfig({
            initialCapital: Capital.wrap(100e18),
            numSwaps: 10,
            swapAmount: 1e18,
            sqrtPriceX96: 79228162514264337593543950336
        });
    }
}
