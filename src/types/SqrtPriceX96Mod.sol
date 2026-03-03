// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type SqrtPriceX96 is uint160;

uint160 constant MIN_SQRT_PRICE = 4295128739;
uint160 constant MAX_SQRT_PRICE = 1461446703485210103287273052203988822378723970342;

error SqrtPriceOutOfBounds(uint160 raw);

function fromUint160(uint160 raw) pure returns (SqrtPriceX96) {
    if (raw < MIN_SQRT_PRICE) revert SqrtPriceOutOfBounds(raw);
    if (raw > MAX_SQRT_PRICE) revert SqrtPriceOutOfBounds(raw);
    return SqrtPriceX96.wrap(raw);
}

function unwrap(SqrtPriceX96 p) pure returns (uint160) {
    return SqrtPriceX96.unwrap(p);
}

using {unwrap} for SqrtPriceX96 global;
