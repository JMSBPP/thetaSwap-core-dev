// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {PosmTestSetup} from "@uniswap/v4-periphery/test/shared/PosmTestSetup.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {PositionManager} from "@uniswap/v4-periphery/src/PositionManager.sol";
import {PositionDescriptor} from "@uniswap/v4-periphery/src/PositionDescriptor.sol";

import {FeeConcentrationIndexHarness} from "../../fee-concentration-index/harness/FeeConcentrationIndexHarness.sol";
import {FCITestHelper} from "../../fee-concentration-index/helpers/FCITestHelper.sol";
import {SqrtPriceLibrary} from "foundational-hooks/src/libraries/SqrtPriceLibrary.sol";

import {Context} from "@foundry-script/types/Context.sol";
import {Protocol} from "@foundry-script/types/Protocol.sol";
import {Scenario, mintPosition, burnPosition} from "@foundry-script/types/Scenario.sol";
import {executeSwapWithAmount} from "@foundry-script/simulation/JitGame.sol";
import "@foundry-script/utils/Constants.sol";

import {FciTokenVaultHarness} from "../helpers/FciTokenVaultHarness.sol";
import {LONG, SHORT} from "@fci-token-vault/modules/CollateralCustodianMod.sol";
import {lookbackPayoffX96, applyDecay} from "@fci-token-vault/libraries/SqrtPriceLookbackPayoffX96Lib.sol";

contract HedgedVsUnhedgedTest is PosmTestSetup, FCITestHelper {
    using PoolIdLibrary for PoolKey;

    Context ctx;
    Scenario scenario;
    FeeConcentrationIndexHarness fciHarness;
    FciTokenVaultHarness vault;
    PoolId poolId;

    // Test parameters
    uint256 constant CAPITAL = 1e18;
    uint256 constant HEDGE_AMOUNT = 0.1e18;
    uint256 constant TRADE_SIZE = 1e15;
    uint256 constant ROUNDS = 3;
    uint256 constant JIT_CAPITAL = 9e18;
    uint256 constant ROUND_INTERVAL = 1 days;

    address hedgedPlpAddr;
    uint256 hedgedPlpPk;
    address unhedgedPlpAddr;
    uint256 unhedgedPlpPk;
    address jitLpAddr;
    uint256 jitLpPk;
    address swapperAddr;
    uint256 swapperPk;
    address depositorAddr;
    uint256 depositorPk;

    function setUp() public {
        // Deploy V4 infrastructure
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        fciLP = makeAddr("defaultLP");
        fciSwapper = address(this);
        fciSwapRouter = swapRouter;

        // Deploy FCI hook via HookMiner
        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_SWAP_FLAG
        );
        bytes memory constructorArgs = abi.encode(address(lpm));
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(FeeConcentrationIndexHarness).creationCode,
            constructorArgs
        );
        fciHarness = new FeeConcentrationIndexHarness{salt: salt}(lpm);
        require(address(fciHarness) == hookAddress, "hook address mismatch");

        // Init pool
        (key, poolId) = initPool(
            currency0, currency1,
            IHooks(address(fciHarness)),
            3000,
            SQRT_PRICE_1_1
        );

        // Wire Context
        ctx.vm = vm;
        ctx.v4Pool = key;
        ctx.v4PositionManager = address(lpm);
        ctx.v4SwapRouter = address(swapRouter);
        ctx.chainId = block.chainid;

        // Deploy vault harness
        vault = new FciTokenVaultHarness();
        // Strike at Δ* = 0.3 (30% fee concentration)
        // Normal passive LP activity stays below this; JIT crowd-out exceeds it
        uint160 strikePrice = SqrtPriceLibrary.fractionToSqrtPriceX96(30, 70);
        // Expiry 5 days: 3 rounds × 1 day = 3 days of pokes, ~2 day gap to settlement.
        // With 14-day half-life, 2 days of decay preserves ~91% of HWM.
        vault.harness_initVault(
            strikePrice,
            14 days,
            block.timestamp + 5 days,
            key,
            false,
            Currency.unwrap(currency1)
        );

        // Create wallets
        Vm.Wallet memory w;
        w = vm.createWallet("hedgedPlp");
        hedgedPlpAddr = w.addr; hedgedPlpPk = w.privateKey;
        w = vm.createWallet("unhedgedPlp");
        unhedgedPlpAddr = w.addr; unhedgedPlpPk = w.privateKey;
        w = vm.createWallet("jitLp");
        jitLpAddr = w.addr; jitLpPk = w.privateKey;
        w = vm.createWallet("swapper");
        swapperAddr = w.addr; swapperPk = w.privateKey;
        w = vm.createWallet("depositor");
        depositorAddr = w.addr; depositorPk = w.privateKey;

        // Fund and approve all actors
        _setupLP(hedgedPlpAddr);
        _setupLP(unhedgedPlpAddr);
        _setupLP(jitLpAddr);
        _setupSwapper(swapperAddr);
        seedBalance(depositorAddr);
    }

    // ═══════════════════════════════════════════════════════════
    // Helpers
    // ═══════════════════════════════════════════════════════════

    function _setupLP(address account) internal {
        seedBalance(account);
        approvePosmFor(account);
    }

    function _setupSwapper(address account) internal {
        seedBalance(account);
        vm.startPrank(account);
        IERC20(Currency.unwrap(currency0)).approve(address(swapRouter), type(uint256).max);
        IERC20(Currency.unwrap(currency1)).approve(address(swapRouter), type(uint256).max);
        vm.stopPrank();
    }

    function _depositToVault(address plpAddr, uint256 amount) internal {
        vm.startPrank(plpAddr);
        IERC20(Currency.unwrap(currency1)).approve(address(vault), amount);
        vault.harness_deposit(plpAddr, amount);
        vm.stopPrank();
    }

    // Block offsets matching Capponi timing model (from JitGame.sol)
    uint256 constant JIT_ENTRY_OFFSET = 49;
    uint256 constant PASSIVE_EXIT_OFFSET = 50;

    /// @dev Execute one complete round following JitGame timing:
    /// Passive LPs enter → roll 49 → JIT enters → swap → JIT exits → roll 50 →
    /// passive LPs exit (triggers FCI observation) → poke() → warp time
    function _runRound(
        bool jitEnters,
        uint256 jitCapital,
        uint256 hedgedLiq,
        uint256 unhedgedLiq
    ) internal returns (uint256 hedgedTokenId, uint256 unhedgedTokenId) {
        // Passive LP entry (block B)
        hedgedTokenId = mintPosition(
            ctx, scenario, Protocol.UniswapV4, hedgedPlpPk, hedgedLiq
        );
        unhedgedTokenId = mintPosition(
            ctx, scenario, Protocol.UniswapV4, unhedgedPlpPk, unhedgedLiq
        );

        // Roll to JIT entry block
        vm.roll(block.number + JIT_ENTRY_OFFSET);

        // JIT entry (if applicable)
        uint256 jitTokenId;
        if (jitEnters) {
            jitTokenId = mintPosition(
                ctx, scenario, Protocol.UniswapV4, jitLpPk, jitCapital
            );
        }

        // Swap
        executeSwapWithAmount(
            ctx, Protocol.UniswapV4, swapperPk, ZERO_FOR_ONE, int256(TRADE_SIZE)
        );

        // JIT exit (next block)
        vm.roll(block.number + 1);
        if (jitEnters) {
            burnPosition(ctx, Protocol.UniswapV4, jitLpPk, jitTokenId, jitCapital);
        }

        // Roll to passive exit — FCI needs afterRemoveLiquidity to observe
        vm.roll(block.number + PASSIVE_EXIT_OFFSET);

        // Passive LP exit — triggers FCI fee concentration observation
        burnPosition(ctx, Protocol.UniswapV4, hedgedPlpPk, hedgedTokenId, hedgedLiq);
        burnPosition(ctx, Protocol.UniswapV4, unhedgedPlpPk, unhedgedTokenId, unhedgedLiq);

        // Advance time + poke vault
        vm.warp(block.timestamp + ROUND_INTERVAL);
        vault.harness_poke();
    }

    /// @dev Settle vault and compute longPayout. Depositor redeems (holds both LONG+SHORT).
    function _settleVault(FciTokenVaultHarness v, uint256 depositAmount)
        internal
        returns (uint256 longPayout, uint256 shortPayout)
    {
        (,,, uint256 expiry,,,,) = v.harness_getVaultStorage();
        vm.warp(expiry + 1);
        v.harness_settle();
        (,,,,,,, uint256 longPayoutPerToken) = v.harness_getVaultStorage();
        longPayout = (depositAmount * longPayoutPerToken) / SqrtPriceLibrary.Q96;
        shortPayout = depositAmount - longPayout;
        vm.prank(depositorAddr);
        v.harness_redeem(depositorAddr, depositAmount);
    }

    /// @dev Measure cumulative welfare: token balances after all rounds vs before any LP activity
    function _snapshotBal(address who) internal view returns (uint256 a, uint256 b) {
        a = IERC20(Currency.unwrap(currency0)).balanceOf(who);
        b = IERC20(Currency.unwrap(currency1)).balanceOf(who);
    }

    // ═══════════════════════════════════════════════════════════
    // Scenario 1: Equilibrium — no JIT
    // ═══════════════════════════════════════════════════════════

    function test_equilibrium_no_jit() public {
        // Depositor funds vault (separate from PLPs)
        _depositToVault(depositorAddr, HEDGE_AMOUNT);

        // Snapshot balances BEFORE LP rounds
        (uint256 hA0, uint256 hB0) = _snapshotBal(hedgedPlpAddr);
        (uint256 uA0, uint256 uB0) = _snapshotBal(unhedgedPlpAddr);

        // Both PLPs provide equal CAPITAL
        for (uint256 i; i < ROUNDS; ++i) {
            _runRound(false, 0, CAPITAL, CAPITAL);
        }

        // Snapshot balances AFTER all rounds (LPs already exited in _runRound)
        (uint256 hA1, uint256 hB1) = _snapshotBal(hedgedPlpAddr);
        (uint256 uA1, uint256 uB1) = _snapshotBal(unhedgedPlpAddr);

        uint256 hedgedPayout = (hA1 + hB1) - (hA0 + hB0);
        uint256 unhedgedPayout = (uA1 + uB1) - (uA0 + uB0);

        (uint256 longPayout, uint256 shortPayout) = _settleVault(vault, HEDGE_AMOUNT);

        uint256 hedgedWelfare = hedgedPayout + longPayout;
        uint256 unhedgedWelfare = unhedgedPayout;

        // Property 2: No false trigger — equal capital, no JIT → equal welfare
        assertEq(longPayout, 0, "LONG should be 0 in equilibrium");
        assertEq(hedgedWelfare, unhedgedWelfare, "equal capital + no JIT = equal welfare");

        // Property 3: Vault solvency
        assertEq(longPayout + shortPayout, HEDGE_AMOUNT, "conservation: long + short = deposit");

        console.log("=== EQUILIBRIUM (no JIT) ===");
        console.log("Hedged payout:", hedgedPayout);
        console.log("Unhedged payout:", unhedgedPayout);
        console.log("LONG payout:", longPayout);
        console.log("Hedged welfare:", hedgedWelfare);
        console.log("Unhedged welfare:", unhedgedWelfare);
    }

    // ═══════════════════════════════════════════════════════════
    // Scenario 2: JIT crowd-out — hedge compensates
    // ═══════════════════════════════════════════════════════════

    function test_jit_crowdout_hedge_compensates() public {
        // Depositor funds vault (separate from PLPs)
        _depositToVault(depositorAddr, HEDGE_AMOUNT);

        (uint256 hA0, uint256 hB0) = _snapshotBal(hedgedPlpAddr);
        (uint256 uA0, uint256 uB0) = _snapshotBal(unhedgedPlpAddr);

        // Both PLPs provide equal CAPITAL
        for (uint256 i; i < ROUNDS; ++i) {
            _runRound(true, JIT_CAPITAL, CAPITAL, CAPITAL);

            // Property 4: HWM captures current price after each poke
            (,uint160 sqrtPriceHWM,,,,,,) = vault.harness_getVaultStorage();
            assertGt(uint256(sqrtPriceHWM), 0, "HWM should be > 0 after JIT round");
        }

        // Record pre-settlement HWM for decay check (Property 5)
        (,uint160 hwmBeforeSettle,,,,,,) = vault.harness_getVaultStorage();

        (uint256 hA1, uint256 hB1) = _snapshotBal(hedgedPlpAddr);
        (uint256 uA1, uint256 uB1) = _snapshotBal(unhedgedPlpAddr);
        uint256 hedgedPayout = (hA1 + hB1) - (hA0 + hB0);
        uint256 unhedgedPayout = (uA1 + uB1) - (uA0 + uB0);

        (uint256 longPayout, uint256 shortPayout) = _settleVault(vault, HEDGE_AMOUNT);

        // Both PLPs earn identical LP returns (equal capital, same pool)
        // Hedged PLP additionally receives longPayout from the insurance mechanism
        uint256 hedgedWelfare = hedgedPayout + longPayout;
        uint256 unhedgedWelfare = unhedgedPayout;

        // Property 1: Payoff compensation — longPayout makes hedged > unhedged
        assertGt(hedgedWelfare, unhedgedWelfare, "hedged should earn more under JIT crowd-out");
        assertGt(longPayout, 0, "LONG should be positive under JIT crowd-out");

        // Property 3: Vault solvency
        assertEq(longPayout + shortPayout, HEDGE_AMOUNT, "conservation: long + short = deposit");

        // Property 5: Decay effect
        (,,uint256 halfLife, uint256 settleExpiry,, uint256 lastHwmTs,,) = vault.harness_getVaultStorage();
        uint256 dt = settleExpiry + 1 - lastHwmTs;
        uint160 decayedHWM = applyDecay(hwmBeforeSettle, dt, halfLife);
        assertLt(uint256(decayedHWM), uint256(hwmBeforeSettle), "decay should reduce HWM");

        console.log("=== JIT CROWD-OUT ===");
        console.log("Hedged payout:", hedgedPayout);
        console.log("Unhedged payout:", unhedgedPayout);
        console.log("LONG payout:", longPayout);
        console.log("Hedged welfare:", hedgedWelfare);
        console.log("Unhedged welfare:", unhedgedWelfare);
        console.log("Net hedge benefit:", hedgedWelfare - unhedgedWelfare);
        console.log("HWM before settle:", uint256(hwmBeforeSettle));
        console.log("HWM after decay:", uint256(decayedHWM));
    }

    // ═══════════════════════════════════════════════════════════
    // Scenario 3: Below-strike JIT — no false trigger
    // ═══════════════════════════════════════════════════════════

    function test_below_strike_no_false_trigger() public {
        // Deploy a SEPARATE vault with very high strike (Δ* ≈ 0.99)
        FciTokenVaultHarness highStrikeVault = new FciTokenVaultHarness();
        uint160 highStrike = SqrtPriceLibrary.fractionToSqrtPriceX96(99, 1);
        highStrikeVault.harness_initVault(
            highStrike, 14 days, block.timestamp + 5 days,
            key, false, Currency.unwrap(currency1)
        );
        // Depositor funds the high-strike vault
        vm.startPrank(depositorAddr);
        IERC20(Currency.unwrap(currency1)).approve(address(highStrikeVault), HEDGE_AMOUNT);
        highStrikeVault.harness_deposit(depositorAddr, HEDGE_AMOUNT);
        vm.stopPrank();

        uint256 smallJitCapital = CAPITAL / 10;

        (uint256 hA0, uint256 hB0) = _snapshotBal(hedgedPlpAddr);
        (uint256 uA0, uint256 uB0) = _snapshotBal(unhedgedPlpAddr);

        for (uint256 i; i < ROUNDS; ++i) {
            // Manual round using highStrikeVault for poke — both PLPs provide equal CAPITAL
            uint256 hTid = mintPosition(ctx, scenario, Protocol.UniswapV4, hedgedPlpPk, CAPITAL);
            uint256 uTid = mintPosition(ctx, scenario, Protocol.UniswapV4, unhedgedPlpPk, CAPITAL);
            vm.roll(block.number + JIT_ENTRY_OFFSET);
            uint256 jTid = mintPosition(ctx, scenario, Protocol.UniswapV4, jitLpPk, smallJitCapital);
            executeSwapWithAmount(ctx, Protocol.UniswapV4, swapperPk, ZERO_FOR_ONE, int256(TRADE_SIZE));
            vm.roll(block.number + 1);
            burnPosition(ctx, Protocol.UniswapV4, jitLpPk, jTid, smallJitCapital);
            vm.roll(block.number + PASSIVE_EXIT_OFFSET);
            burnPosition(ctx, Protocol.UniswapV4, hedgedPlpPk, hTid, CAPITAL);
            burnPosition(ctx, Protocol.UniswapV4, unhedgedPlpPk, uTid, CAPITAL);
            vm.warp(block.timestamp + ROUND_INTERVAL);
            highStrikeVault.harness_poke();
        }

        (uint256 hA1, uint256 hB1) = _snapshotBal(hedgedPlpAddr);
        (uint256 uA1, uint256 uB1) = _snapshotBal(unhedgedPlpAddr);
        uint256 hedgedPayout = (hA1 + hB1) - (hA0 + hB0);
        uint256 unhedgedPayout = (uA1 + uB1) - (uA0 + uB0);

        (uint256 longPayout, uint256 shortPayout) = _settleVault(highStrikeVault, HEDGE_AMOUNT);

        uint256 hedgedWelfare = hedgedPayout + longPayout;
        uint256 unhedgedWelfare = unhedgedPayout;

        // Property 2: No false trigger — equal capital, below strike → equal welfare
        assertEq(longPayout, 0, "LONG should be 0 when below strike");
        assertEq(hedgedWelfare, unhedgedWelfare, "equal capital + below strike = equal welfare");

        // Property 3: Vault solvency
        assertEq(longPayout + shortPayout, HEDGE_AMOUNT, "conservation: long + short = deposit");

        console.log("=== BELOW-STRIKE JIT ===");
        console.log("Hedged payout:", hedgedPayout);
        console.log("Unhedged payout:", unhedgedPayout);
        console.log("LONG payout:", longPayout);
        console.log("Hedged welfare:", hedgedWelfare);
        console.log("Unhedged welfare:", unhedgedWelfare);
    }
}
