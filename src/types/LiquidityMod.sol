// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type Liquidity is uint128;

function unwrap(Liquidity l) pure returns (uint128) {
    return Liquidity.unwrap(l);
}

function isZero(Liquidity l) pure returns (bool) {
    return Liquidity.unwrap(l) == 0;
}

using {unwrap, isZero} for Liquidity global;
