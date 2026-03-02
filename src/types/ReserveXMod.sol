// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type ReserveX is uint256;

function unwrap(ReserveX x) pure returns (uint256) {
    return ReserveX.unwrap(x);
}

function isZero(ReserveX x) pure returns (bool) {
    return ReserveX.unwrap(x) == 0;
}

using {unwrap, isZero} for ReserveX global;
