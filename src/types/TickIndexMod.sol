// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type TickIndex is int24;

int24 constant MIN_TICK = -887272;
int24 constant MAX_TICK = 887272;

error TickOutOfBounds(int24 raw);

function fromInt24(int24 raw) pure returns (TickIndex) {
    if (raw < MIN_TICK) revert TickOutOfBounds(raw);
    if (raw > MAX_TICK) revert TickOutOfBounds(raw);
    return TickIndex.wrap(raw);
}

function unwrap(TickIndex t) pure returns (int24) {
    return TickIndex.unwrap(t);
}

using {unwrap} for TickIndex global;
