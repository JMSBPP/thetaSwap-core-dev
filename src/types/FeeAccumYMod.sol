// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type FeeAccumY is uint256;

function unwrap(FeeAccumY f) pure returns (uint256) {
    return FeeAccumY.unwrap(f);
}

function add(FeeAccumY a, FeeAccumY b) pure returns (FeeAccumY) {
    return FeeAccumY.wrap(FeeAccumY.unwrap(a) + FeeAccumY.unwrap(b));
}

using {unwrap, add as +} for FeeAccumY global;
