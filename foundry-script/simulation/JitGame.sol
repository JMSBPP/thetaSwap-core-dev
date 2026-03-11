// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Vm} from "forge-std/Vm.sol";
import {Protocol} from "@foundry-script/types/Protocol.sol";

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
