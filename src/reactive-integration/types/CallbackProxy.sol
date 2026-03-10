// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type CallbackProxy is address;

function toAddress(CallbackProxy proxy) pure returns (address) {
    return CallbackProxy.unwrap(proxy);
}
