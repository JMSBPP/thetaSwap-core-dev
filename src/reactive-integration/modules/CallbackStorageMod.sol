// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RvmId} from "../types/RvmId.sol";
import {CallbackProxy} from "../types/CallbackProxy.sol";

struct CallbackStorage {
    RvmId rvmId;
    CallbackProxy callbackProxy;
}

bytes32 constant CALLBACK_STORAGE_SLOT = keccak256("reactive.callback.storage");

function callbackStorage() pure returns (CallbackStorage storage $) {
    bytes32 slot = CALLBACK_STORAGE_SLOT;
    assembly ("memory-safe") {
        $.slot := slot
    }
}

function getRvmId() view returns (RvmId) {
    return callbackStorage().rvmId;
}

function setRvmId(RvmId id) {
    callbackStorage().rvmId = id;
}

function getCallbackProxy() view returns (CallbackProxy) {
    return callbackStorage().callbackProxy;
}

function setCallbackProxy(CallbackProxy proxy) {
    callbackStorage().callbackProxy = proxy;
}
