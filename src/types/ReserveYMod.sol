// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type ReserveY is uint256;

function unwrap(ReserveY y) pure returns (uint256) {
    return ReserveY.unwrap(y);
}

function isZero(ReserveY y) pure returns (bool) {
    return ReserveY.unwrap(y) == 0;
}

using {unwrap, isZero} for ReserveY global;
