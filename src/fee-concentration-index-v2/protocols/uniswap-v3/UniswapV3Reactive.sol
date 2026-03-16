// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IReactive} from "reactive-lib/interfaces/IReactive.sol";
import {ISubscriptionService} from "reactive-lib/interfaces/ISubscriptionService.sol";
import {coverDebt, depositToSystem} from "reactive-hooks/modules/DebtMod.sol";
import {SYSTEM_CONTRACT} from "reactive-hooks/libraries/DebtLib.sol";
import {requireVM} from "reactive-hooks/modules/ReactVMMod.sol";
import {isReactiveVm, isActive} from "reactive-hooks/types/ReactVM.sol";
import {REACTIVE_IGNORE} from "reactive-hooks/libraries/SubscriptionLib.sol";
import {POOL_ADDED_SIG} from "@fee-concentration-index-v2/libraries/PoolAddedSig.sol";
import {handlePoolAdded, dispatchEvent} from "@fee-concentration-index-v2/modules/ReactiveDispatchMod.sol";

/// @title UniswapV3Reactive
/// @dev Reactive Network contract for V3 reactive integration.
/// Dual-instance: RN subscribes to PoolAdded from facet on origin chain,
/// ReactVM auto-subscribes to V3 pool events via EDT + dispatches to callback.
contract UniswapV3Reactive {
    ISubscriptionService immutable service;

    constructor(uint256 originChainId, address facetAddress) payable {
        service = ISubscriptionService(SYSTEM_CONTRACT);

        if (!isActive(isReactiveVm())) {
            // Subscribe to PoolAdded events from the facet on the origin chain
            service.subscribe(originChainId, facetAddress, POOL_ADDED_SIG, REACTIVE_IGNORE, REACTIVE_IGNORE, REACTIVE_IGNORE);
            depositToSystem(address(this));
        }
    }

    function react(IReactive.LogRecord calldata log) external {
        requireVM();

        if (log.topic_0 == POOL_ADDED_SIG) {
            handlePoolAdded(log, service);
            return;
        }

        dispatchEvent(log);
    }

    function fund() external payable {
        depositToSystem(address(this));
    }

    receive() external payable {
        coverDebt(address(this));
    }
}
