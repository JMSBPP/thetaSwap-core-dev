// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type EntryCount is uint256;

function unwrap(EntryCount n) pure returns (uint256) {
    return EntryCount.unwrap(n);
}

function increment(EntryCount n) pure returns (EntryCount) {
    return EntryCount.wrap(EntryCount.unwrap(n) + 1);
}

function isZero(EntryCount n) pure returns (bool) {
    return EntryCount.unwrap(n) == 0;
}

using {unwrap, increment, isZero} for EntryCount global;
