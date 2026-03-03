// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type FeeRate is uint24;

uint24 constant MAX_FEE = 1000000;

error FeeAboveMax(uint24 raw);

function fromUint24(uint24 raw) pure returns (FeeRate) {
    if (raw > MAX_FEE) revert FeeAboveMax(raw);
    return FeeRate.wrap(raw);
}

function unwrap(FeeRate f) pure returns (uint24) {
    return FeeRate.unwrap(f);
}

using {unwrap} for FeeRate global;
