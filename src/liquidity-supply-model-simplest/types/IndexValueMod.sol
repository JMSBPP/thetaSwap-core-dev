// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {EntryCount} from "./EntryCountMod.sol";

type IndexValue is uint256;

function unwrap(IndexValue v) pure returns (uint256) {
    return IndexValue.unwrap(v);
}

function fromEntryCount(EntryCount n) pure returns (IndexValue) {
    return IndexValue.wrap(EntryCount.unwrap(n));
}

using {unwrap} for IndexValue global;
