// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type FeeRevenue is uint256;

function unwrap(FeeRevenue f) pure returns (uint256) {
    return FeeRevenue.unwrap(f);
}

function add(FeeRevenue a, FeeRevenue b) pure returns (FeeRevenue) {
    return FeeRevenue.wrap(FeeRevenue.unwrap(a) + FeeRevenue.unwrap(b));
}

using {unwrap, add as +} for FeeRevenue global;
