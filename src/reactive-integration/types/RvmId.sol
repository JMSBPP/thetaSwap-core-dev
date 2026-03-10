// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type RvmId is address;

function rvmIdPlaceHolder() pure returns(RvmId){
    return RvmId.wrap(address(0x00));
}

function toAddress(RvmId id) pure returns (address) {
    return RvmId.unwrap(id);
}
