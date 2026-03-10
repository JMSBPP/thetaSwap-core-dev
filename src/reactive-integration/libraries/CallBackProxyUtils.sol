// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

// ── PSEUDO-CODE: Callback proxy network registry ──
// TODO(refactor): uncomment when compose/OwnerMod + AccessControlMod are available
//
// import {OwnerMod} from "compose/src/OwnerMod.sol";
// import {AccessControlMod} from "compose/src/AccessControlMod.sol";
//
// struct CallbackProxyNetworkRegistry{
//     address rvmId;
//     mapping(uint256 chainId => address callBackProxy) callbackRegistry;
// }
//
// bytes32 constant CALLBACK_PROXY_NETWORK_REGISTRY = keccak256("thetaSwap.callbackProxyNetworkRegistry");
//
// function setRvmId(address _rvmId) pure {
//     OwnerMod.requireOwner();
//     CallbackProxyNetworkRegistry storage $ = callbackProxyNetworkRegistry();
//     $.rvmId = _rvmId;
// }
//
// function rvmId() pure returns(address){
//     CallbackProxyNetworkRegistry storage $ = callbackProxyNetworkRegistry();
//     return $.rvmId;
// }
//
// function callbackProxyNetworkRegistry() pure returns(CallbackProxyNetworkRegistry storage $){
//     bytes32 pos;
//     assembly("memory-safe"){
//          pos := $.slot
//     }
// }
//
// function sstoreCallbackProxy(uint256 chainId, address callbackProxy) {
//     OwnerMod.requireOwner();
//     CallbackProxyNetworkRegistry storage $  = callbackProxyNetworkRegistry();
//     $.callbackRegistry[chainId] = callbackProxy;
// }
//
// function sloadCallbackProxy(uint256 chainId) pure returns(address){
//     CallbackProxyNetworkRegistry storage $  = callbackProxyNetworkRegistry();
//     return $.callbackRegistry[chainId];
// }
//
// note: setAuthorized is replaced by access control guarded by owner
// ── END PSEUDO-CODE ──
