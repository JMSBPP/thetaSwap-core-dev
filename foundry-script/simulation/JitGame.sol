// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {Protocol} from "@foundry-script/types/Protocol.sol";
import {DEFAULT_DERIVATION_PATH} from "@foundry-script/types/Accounts.sol";

struct JitGameConfig {
    uint256 n;
    uint256 jitCapital;
    uint256 jitEntryProbability;
    uint256 tradeSize;
    bool zeroForOne;
    Protocol protocol;
}

struct JitGameResult {
    uint128 deltaPlus;
    uint256 hedgedLpPayout;
    uint256 unhedgedLpPayout;
    uint256 jitLpPayout;
    bool jitEntered;
}

struct JitAccounts {
    Vm.Wallet[] passiveLps;
    Vm.Wallet jitLp;
    Vm.Wallet swapper;
    uint256 hedgedIndex;
}

function initJitAccounts(Vm vm, uint256 n) returns (JitAccounts memory acc) {
    require(n >= 2, "JitGame: N must be >= 2");
    string memory mnemonic = vm.envString("MNEMONIC");

    acc.passiveLps = new Vm.Wallet[](n);
    for (uint256 i; i < n; ++i) {
        acc.passiveLps[i] = vm.createWallet(
            vm.deriveKey(mnemonic, DEFAULT_DERIVATION_PATH, uint32(i)),
            string.concat("passiveLp", vm.toString(i))
        );
    }
    acc.jitLp = vm.createWallet(
        vm.deriveKey(mnemonic, DEFAULT_DERIVATION_PATH, uint32(n)),
        "jitLp"
    );
    acc.swapper = vm.createWallet(
        vm.deriveKey(mnemonic, DEFAULT_DERIVATION_PATH, uint32(n + 1)),
        "swapper"
    );
    acc.hedgedIndex = 0;
}
