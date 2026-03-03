// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

type SwapVolume is uint256;

function unwrap(SwapVolume v) pure returns (uint256) {
    return SwapVolume.unwrap(v);
}

function isZero(SwapVolume v) pure returns (bool) {
    return SwapVolume.unwrap(v) == 0;
}

using {unwrap, isZero} for SwapVolume global;
