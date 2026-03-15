// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {UNISWAP_V3} from "@fee-concentration-index-v2/types/FlagsRegistry.sol";

/// @title UniswapV3Callback
/// @dev Receives reactive callbacks from the Reactive Network callback proxy.
/// Decodes V3 event data, encodes hookData with UNISWAP_V3 flag,
/// and calls FCI V2's hook functions.
/// Implements IUnlockCallbackReactiveExt without explicit inheritance (SCOP).
contract UniswapV3Callback {

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        // TODO: implement V4 PoolManager unlock path (if needed)
    }

    function unlockCallbackReactive(address rvmId, bytes calldata data) external {
        // TODO: decode V3 event data, encode hookData with UNISWAP_V3 flag,
        // call FCI V2 hook functions (afterAddLiquidity, beforeSwap, etc.)
    }
}
