// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {console2} from "forge-std/console2.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IFeeConcentrationIndex} from "../../src/fee-concentration-index/interfaces/IFeeConcentrationIndex.sol";
import {
    Scenario,
    Recipe,
    deltaPlusFactory,
    registerV3Pool,
    poolKey,
    selectRecipe,
    recipeCrowdout,
    crowdoutPhase1,
    crowdoutPhase2,
    crowdoutPhase3,
    DELTA_EQUILIBRIUM,
    DELTA_MILD,
    DELTA_CROWDOUT
} from "../types/Scenario.sol";
import {Protocol} from "../types/Protocol.sol";

// Broadcasts real transactions to fabricate a target delta-plus on-chain.
// The reactive adapter hears the V3 Mint/Burn/Swap events and updates FCI.
//
// Usage:
//   # Single-block recipes (equilibrium, mild):
//   forge script FeeConcentrationIndexBuilderScript --sig "buildEquilibrium()" --broadcast --rpc-url $SEPOLIA_RPC_URL
//   forge script FeeConcentrationIndexBuilderScript --sig "buildMild()" --broadcast --rpc-url $SEPOLIA_RPC_URL
//
//   # Multi-block recipe (crowdout) — 3 separate invocations:
//   forge script FeeConcentrationIndexBuilderScript --sig "buildCrowdoutPhase1()" --broadcast --rpc-url $SEPOLIA_RPC_URL
//   # ... wait N blocks ...
//   forge script FeeConcentrationIndexBuilderScript --sig "buildCrowdoutPhase2()" --broadcast --rpc-url $SEPOLIA_RPC_URL
//   # ... wait N blocks ...
//   forge script FeeConcentrationIndexBuilderScript --sig "buildCrowdoutPhase3()" --broadcast --rpc-url $SEPOLIA_RPC_URL
//
// Required .env:
//   SEPOLIA_POOL, ADAPTER_ADDRESS, HARNESS_ADDRESS, SEPOLIA_CHAIN_ID,
//   LP_PASSIVE_PK, LP_SOPHISTICATED_PK, SWAPPER_PK
//   TOKEN_A (for phased crowdout — set after phase 1)

contract FeeConcentrationIndexBuilderScript is Script, StdAssertions {
    Scenario internal scenario;

    uint256 internal lpPassivePK;
    uint256 internal lpSophisticatedPK;
    uint256 internal swapperPK;
    uint256 internal chainId;

    IFeeConcentrationIndex internal fciIndex;

    function setUp() public {
        scenario.vm = vm;

        lpPassivePK = vm.envUint("LP_PASSIVE_PK");
        lpSophisticatedPK = vm.envUint("LP_SOPHISTICATED_PK");
        swapperPK = vm.envUint("SWAPPER_PK");
        chainId = vm.envUint("SEPOLIA_CHAIN_ID");

        registerV3Pool(
            scenario,
            chainId,
            IUniswapV3Pool(vm.envAddress("SEPOLIA_POOL")),
            vm.envAddress("ADAPTER_ADDRESS")
        );

        fciIndex = IFeeConcentrationIndex(vm.envAddress("HARNESS_ADDRESS"));
    }

    // ── Single-block recipes ──

    function buildEquilibrium() public {
        deltaPlusFactory(
            scenario, chainId, Protocol.UniswapV3,
            lpPassivePK, lpSophisticatedPK, swapperPK,
            DELTA_EQUILIBRIUM
        );
        _logDeltaPlus("equilibrium");
    }

    function buildMild() public {
        deltaPlusFactory(
            scenario, chainId, Protocol.UniswapV3,
            lpPassivePK, lpSophisticatedPK, swapperPK,
            DELTA_MILD
        );
        _logDeltaPlus("mild");
    }

    // ── Multi-block recipe: crowdout (US3-F) ──
    // Run each phase as a separate script invocation with block gaps between.

    function buildCrowdoutPhase1() public {
        Recipe memory r = recipeCrowdout();
        uint256 tokenA = crowdoutPhase1(
            scenario, chainId, Protocol.UniswapV3,
            lpPassivePK, r.capitalA
        );
        console2.log("Phase 1 complete. TOKEN_A=%d", tokenA);
        console2.log("Wait for blocks, then run buildCrowdoutPhase2()");
    }

    function buildCrowdoutPhase2() public {
        Recipe memory r = recipeCrowdout();
        uint256 tokenB = crowdoutPhase2(
            scenario, chainId, Protocol.UniswapV3,
            lpSophisticatedPK, swapperPK, r.capitalB
        );
        console2.log("Phase 2 complete. TOKEN_B=%d (already burned)", tokenB);
        console2.log("Wait for blocks, then run buildCrowdoutPhase3()");
    }

    function buildCrowdoutPhase3() public {
        Recipe memory r = recipeCrowdout();
        uint256 tokenA = vm.envUint("TOKEN_A");
        crowdoutPhase3(
            scenario, chainId, Protocol.UniswapV3,
            lpPassivePK, swapperPK, tokenA, r.capitalA
        );
        _logDeltaPlus("crowdout");
    }

    // ── Assertion helper ──

    function assertDeltaPlus(uint128 target, bool reactive) public view {
        PoolKey memory k = poolKey(scenario, chainId);
        uint128 actual = fciIndex.getDeltaPlus(k, reactive);
        assertApproxEqRel(
            uint256(actual),
            uint256(target),
            0.05e18,
            "deltaPlus diverged from target"
        );
    }

    function _logDeltaPlus(string memory label) internal view {
        PoolKey memory k = poolKey(scenario, chainId);
        uint128 dp = fciIndex.getDeltaPlus(k, true);
        console2.log("[%s] deltaPlus (reactive) = %d", label, uint256(dp));
    }
}
