// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {RvmId, toAddress} from "../types/RvmId.sol";
import {CallbackProxy, toAddress} from "../types/CallbackProxy.sol";
import {getRvmId, getCallbackProxy} from "./CallbackStorageMod.sol";

error InvalidRvmId();
error NotCallbackProxy();
error InsufficientFunds();
error TransferFailed();

function requireCallbackProxy(address sender) view {
    if (sender != toAddress(getCallbackProxy())) revert NotCallbackProxy();
}

function requireRvmId(address rvmSender) view {
    if (rvmSender != toAddress(getRvmId())) revert InvalidRvmId();
}

function requireCallback(address sender, address rvmSender) view {
    requireCallbackProxy(sender);
    requireRvmId(rvmSender);
}

function pay(address sender, uint256 amount, address self) {
    requireCallbackProxy(sender);
    if (self.balance < amount) revert InsufficientFunds();
    if (amount > 0) {
        (bool success,) = payable(sender).call{value: amount}("");
        if (!success) revert TransferFailed();
    }
}
