// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type Capital is uint256;

function unwrap(Capital c) pure returns (uint256) {
    return Capital.unwrap(c);
}

function add(Capital a, Capital b) pure returns (Capital) {
    return Capital.wrap(Capital.unwrap(a) + Capital.unwrap(b));
}

function sub(Capital a, Capital b) pure returns (Capital) {
    return Capital.wrap(Capital.unwrap(a) - Capital.unwrap(b));
}

function eq(Capital a, Capital b) pure returns (bool) {
    return Capital.unwrap(a) == Capital.unwrap(b);
}

using {unwrap, add as +, sub as -, eq} for Capital global;
