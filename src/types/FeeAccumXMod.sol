// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type FeeAccumX is uint256;

function unwrap(FeeAccumX f) pure returns (uint256) {
    return FeeAccumX.unwrap(f);
}

function add(FeeAccumX a, FeeAccumX b) pure returns (FeeAccumX) {
    return FeeAccumX.wrap(FeeAccumX.unwrap(a) + FeeAccumX.unwrap(b));
}

using {unwrap, add as +} for FeeAccumX global;
