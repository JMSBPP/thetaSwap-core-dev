// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {PosmTestSetup} from "@uniswap/v4-periphery/test/shared/PosmTestSetup.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

// Force-compile artifacts so vm.getCode can find them (used by Deploy.sol in PosmTestSetup)
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {PositionDescriptor} from "@uniswap/v4-periphery/src/PositionDescriptor.sol";

import {Context} from "@foundry-script/types/Context.sol";
import {Protocol} from "@foundry-script/types/Protocol.sol";
import {Scenario} from "@foundry-script/types/Scenario.sol";
import {
    JitGameConfig,
    JitGameResult,
    JitAccounts,
    initJitAccounts,
    runJitGame,
    UNIT_LIQUIDITY
} from "@foundry-script/simulation/JitGame.sol";
import "@foundry-script/utils/Constants.sol";

contract CapponiJITSequentialGameForkTest is PosmTestSetup {
    Context ctx;
    Scenario scenario;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        (key,) = initPool(
            currency0,
            currency1,
            IHooks(address(0)),
            3000,
            TickMath.getSqrtPriceAtTick(0)
        );

        ctx.vm = vm;
        ctx.v4Pool = key;
        ctx.v4PositionManager = address(lpm);
        ctx.v4SwapRouter = address(swapRouter);
        ctx.chainId = block.chainid;
    }

    /// @dev Fund an address with tokens and ETH, approve permit2 + posm for PositionManager usage.
    function _fundAndApproveForPosm(address account, uint256 amount0, uint256 amount1) internal {
        vm.deal(account, 1 ether);
        deal(Currency.unwrap(currency0), account, amount0);
        deal(Currency.unwrap(currency1), account, amount1);

        vm.startPrank(account);
        // Approve permit2 on both tokens
        IERC20(Currency.unwrap(currency0)).approve(address(permit2), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(permit2), type(uint256).max);
        // Approve posm as permit2 spender
        permit2.approve(Currency.unwrap(currency0), address(lpm), type(uint160).max, type(uint48).max);
        permit2.approve(Currency.unwrap(currency1), address(lpm), type(uint160).max, type(uint48).max);
        vm.stopPrank();
    }

    /// @dev Fund an address with tokens and ETH, approve swapRouter directly (no permit2 needed).
    function _fundAndApproveForSwap(address account, uint256 amount0, uint256 amount1) internal {
        vm.deal(account, 1 ether);
        deal(Currency.unwrap(currency0), account, amount0);
        deal(Currency.unwrap(currency1), account, amount1);

        vm.startPrank(account);
        IERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function test_jitGame_equilibrium_no_jit_entry() public {
        uint256 n = 5;
        JitAccounts memory acc = initJitAccounts(vm, n);

        // Fund and approve all passive LPs for PositionManager (permit2 flow)
        for (uint256 i; i < n; ++i) {
            _fundAndApproveForPosm(acc.passiveLps[i].addr, UNIT_LIQUIDITY, UNIT_LIQUIDITY);
        }
        // Fund and approve swapper for SwapRouter (direct approval)
        _fundAndApproveForSwap(acc.swapper.addr, UNIT_LIQUIDITY * 10, UNIT_LIQUIDITY * 10);

        JitGameConfig memory cfg = JitGameConfig({
            n: n,
            jitCapital: 5e18,
            jitEntryProbability: 0, // JIT never enters
            tradeSize: 1e15,
            zeroForOne: true,
            protocol: Protocol.UniswapV4
        });

        JitGameResult memory result = runJitGame(ctx, scenario, cfg, acc);

        assertFalse(result.jitEntered, "JIT should not enter at 0% probability");
        assertEq(result.jitLpPayout, 0, "JIT payout should be 0 when not entered");
        assertApproxEqAbs(result.deltaPlus, 0, 1e30, "delta-plus should be ~0 with equal LPs");
    }

    function test_jitGame_concentration_with_guaranteed_jit() public {
        uint256 n = 3;
        JitAccounts memory acc = initJitAccounts(vm, n);

        // Fund and approve passive LPs
        for (uint256 i; i < n; ++i) {
            _fundAndApproveForPosm(acc.passiveLps[i].addr, UNIT_LIQUIDITY, UNIT_LIQUIDITY);
        }
        // Fund and approve JIT LP
        _fundAndApproveForPosm(acc.jitLp.addr, 10e18, 10e18);
        // Fund and approve swapper
        _fundAndApproveForSwap(acc.swapper.addr, UNIT_LIQUIDITY * 10, UNIT_LIQUIDITY * 10);

        JitGameConfig memory cfg = JitGameConfig({
            n: n,
            jitCapital: 10e18,
            jitEntryProbability: 10000, // JIT always enters
            tradeSize: 1e15,
            zeroForOne: true,
            protocol: Protocol.UniswapV4
        });

        JitGameResult memory result = runJitGame(ctx, scenario, cfg, acc);

        assertTrue(result.jitEntered, "JIT should enter at 100% probability");
        assertTrue(result.jitLpPayout > 0, "JIT should earn fees");
        console.log("Delta-plus (Q128):", uint256(result.deltaPlus));
        console.log("JIT payout:", result.jitLpPayout);
        console.log("Hedged LP payout:", result.hedgedLpPayout);
        console.log("Unhedged LP payout:", result.unhedgedLpPayout);
    }
}
