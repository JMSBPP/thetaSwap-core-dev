// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {FeeConcentrationIndex} from "@fee-concentration-index/FeeConcentrationIndex.sol";

// Pre-calculated: AFTER_ADD_LIQUIDITY | BEFORE_REMOVE_LIQUIDITY | AFTER_REMOVE_LIQUIDITY | BEFORE_SWAP | AFTER_SWAP
// = (1<<10) | (1<<9) | (1<<8) | (1<<7) | (1<<6) = 0x7C0
uint160 constant FCI_HOOK_FLAGS = 0x7C0;

contract DeployFci is Script {
    IPoolManager public immutable poolManager;

    constructor(address poolManager_) {
        poolManager = IPoolManager(poolManager_);
    }

    function run() public returns (address hookAddress) {
        bytes memory constructorArgs = abi.encode(address(poolManager));
        (address addr, bytes32 salt) = HookMiner.find(
            msg.sender, FCI_HOOK_FLAGS,
            type(FeeConcentrationIndex).creationCode, constructorArgs
        );

        vm.broadcast();
        FeeConcentrationIndex fci = new FeeConcentrationIndex{salt: salt}(address(poolManager));
        require(address(fci) == addr, "DeployFci: hook address mismatch");

        hookAddress = address(fci);
    }
}
