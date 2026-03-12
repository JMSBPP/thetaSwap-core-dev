// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {JitAccounts, JitGameConfig, JitGameResult, initJitAccounts, validateJitConfig, computeDeltaPlus} from
    "@foundry-script/simulation/JitGame.sol";
import {Protocol} from "@foundry-script/types/Protocol.sol";

contract JitGameAccountsTestHelper {
    function callInitJitAccounts(Vm vm, uint256 n) external returns (JitAccounts memory) {
        return initJitAccounts(vm, n);
    }
}

contract JitGameAccountsTest is Test {
    JitGameAccountsTestHelper internal helper;

    function setUp() public {
        helper = new JitGameAccountsTestHelper();
    }

    function test_initJitAccounts_generates_correct_count() public {
        uint256 n = 5;
        JitAccounts memory acc = initJitAccounts(vm, n);

        assertEq(acc.passiveLps.length, n, "should generate N passive LPs");
        assertTrue(acc.jitLp.addr != address(0), "JIT LP should have nonzero address");
        assertTrue(acc.swapper.addr != address(0), "swapper should have nonzero address");
        assertEq(acc.hedgedIndex, 0, "hedgedIndex should default to 0");
    }

    function test_initJitAccounts_all_addresses_unique() public {
        uint256 n = 10;
        JitAccounts memory acc = initJitAccounts(vm, n);

        for (uint256 i; i < n; ++i) {
            for (uint256 j = i + 1; j < n; ++j) {
                assertTrue(
                    acc.passiveLps[i].addr != acc.passiveLps[j].addr,
                    "passive LP addresses must be unique"
                );
            }
            assertTrue(
                acc.passiveLps[i].addr != acc.jitLp.addr,
                "passive LP must differ from JIT LP"
            );
            assertTrue(
                acc.passiveLps[i].addr != acc.swapper.addr,
                "passive LP must differ from swapper"
            );
        }
        assertTrue(acc.jitLp.addr != acc.swapper.addr, "JIT LP must differ from swapper");
    }

    function test_initJitAccounts_reverts_below_minimum() public {
        vm.expectRevert("JitGame: N must be >= 2");
        helper.callInitJitAccounts(vm, 1);
    }

    function test_initJitAccounts_reverts_zero() public {
        vm.expectRevert("JitGame: N must be >= 2");
        helper.callInitJitAccounts(vm, 0);
    }
}

contract JitGameConfigTestHelper {
    function callValidateJitConfig(JitGameConfig memory cfg) external pure {
        validateJitConfig(cfg);
    }
}

contract JitGameConfigTest is Test {
    JitGameConfigTestHelper internal helper;

    function setUp() public {
        helper = new JitGameConfigTestHelper();
    }

    function test_validateJitConfig_reverts_n_below_2() public {
        JitGameConfig memory cfg = JitGameConfig({
            n: 1, jitCapital: 1e18, jitEntryProbability: 5000,
            tradeSize: 1e18, zeroForOne: true, protocol: Protocol.UniswapV4
        });
        vm.expectRevert("JitGame: N must be >= 2");
        helper.callValidateJitConfig(cfg);
    }

    function test_validateJitConfig_reverts_probability_over_10000() public {
        JitGameConfig memory cfg = JitGameConfig({
            n: 5, jitCapital: 1e18, jitEntryProbability: 10001,
            tradeSize: 1e18, zeroForOne: true, protocol: Protocol.UniswapV4
        });
        vm.expectRevert("JitGame: probability must be <= 10000 bps");
        helper.callValidateJitConfig(cfg);
    }

    function test_validateJitConfig_reverts_zero_tradeSize() public {
        JitGameConfig memory cfg = JitGameConfig({
            n: 5, jitCapital: 1e18, jitEntryProbability: 5000,
            tradeSize: 0, zeroForOne: true, protocol: Protocol.UniswapV4
        });
        vm.expectRevert("JitGame: tradeSize must be > 0");
        helper.callValidateJitConfig(cfg);
    }

    function test_validateJitConfig_accepts_valid() public pure {
        JitGameConfig memory cfg = JitGameConfig({
            n: 10, jitCapital: 5e18, jitEntryProbability: 7000,
            tradeSize: 1e18, zeroForOne: true, protocol: Protocol.UniswapV4
        });
        validateJitConfig(cfg);
    }
}

contract ComputeDeltaPlusTest is Test {
    /// All equal payouts → HHI = 1/N → delta-plus = 0
    function test_computeDeltaPlus_equilibrium() public pure {
        uint256[] memory payouts = new uint256[](4);
        payouts[0] = 100;
        payouts[1] = 100;
        payouts[2] = 100;
        payouts[3] = 100;
        uint128 dp = computeDeltaPlus(payouts, 4);
        assertEq(dp, 0, "equal payouts should give delta-plus = 0");
    }

    /// One LP gets everything → HHI = 1 → delta-plus = 1 - 1/N
    function test_computeDeltaPlus_monopoly() public pure {
        uint256[] memory payouts = new uint256[](4);
        payouts[0] = 1000;
        payouts[1] = 0;
        payouts[2] = 0;
        payouts[3] = 0;
        uint128 dp = computeDeltaPlus(payouts, 4);
        // delta-plus = 1 - 0.25 = 0.75 in Q128
        uint128 expected = uint128((75e16 << 128) / 1e18);
        // Allow 1 unit rounding
        assertApproxEqAbs(dp, expected, 1, "monopoly should give delta-plus ~ 0.75");
    }

    /// Zero total payout → delta-plus = 0
    function test_computeDeltaPlus_zero_total() public pure {
        uint256[] memory payouts = new uint256[](3);
        uint128 dp = computeDeltaPlus(payouts, 3);
        assertEq(dp, 0, "zero fees should give delta-plus = 0");
    }

    /// Two LPs, 1:2 split → HHI = (1/3)^2 + (2/3)^2 = 5/9
    /// delta-plus = 5/9 - 1/2 = 1/18 ≈ 0.0556
    function test_computeDeltaPlus_mild_concentration() public pure {
        uint256[] memory payouts = new uint256[](2);
        payouts[0] = 1e18;
        payouts[1] = 2e18;
        uint128 dp = computeDeltaPlus(payouts, 2);
        // 1/18 in Q128
        uint128 expected = uint128((uint256(1e18) / 18 << 128) / 1e18);
        assertApproxEqAbs(dp, expected, 1e30, "1:2 split should give delta-plus ~ 0.0556");
    }
}
