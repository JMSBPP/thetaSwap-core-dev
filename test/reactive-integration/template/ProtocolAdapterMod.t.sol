// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId} from "v4-core/src/types/PoolId.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {
    ProtocolAdapterStorage,
    V4_ADAPTER_SLOT, V3_ADAPTER_SLOT,
    protocolAdapterStorage
} from "@protocol-adapter/storage/ProtocolAdapterStorage.sol";
import {
    initializeAdapter,
    incrementPosCount
} from "@protocol-adapter/modules/ProtocolAdapterMod.sol";
import {
    FeeConcentrationIndexStorage,
    fciStorage, reactiveFciStorage
} from "@fee-concentration-index/modules/FeeConcentrationIndexStorageMod.sol";

contract InitializeAdapterCaller {
    function doInit(
        bytes32 slot,
        address protocolState,
        IHooks fciEntryPoint,
        PoolKey calldata poolKey,
        bool reactive
    ) external {
        initializeAdapter(slot, protocolState, fciEntryPoint, poolKey, reactive);
    }

    function readAdapter(bytes32 slot) external view returns (
        address protocolState,
        address fciEntryPoint,
        uint24 fee,
        bool reactive
    ) {
        ProtocolAdapterStorage storage $ = protocolAdapterStorage(slot);
        return ($.protocolState, address($.fciEntryPoint), $.poolKey.fee, $.reactive);
    }
}

/// @dev Wrapper to call incrementPosCount with hookData dispatch.
/// Needed because free functions with calldata params require an external call boundary.
/// Also exposes storage reads so the test can verify state written in this contract's context.
contract DispatchCaller {
    function doIncrementPosCount(bytes calldata hookData, PoolId poolId) external {
        incrementPosCount(hookData, poolId);
    }

    function readV4PosCount(PoolId poolId) external view returns (uint256) {
        return fciStorage().fciState[poolId].posCount;
    }

    function readV3PosCount(PoolId poolId) external view returns (uint256) {
        return reactiveFciStorage().fciState[poolId].posCount;
    }
}

contract ProtocolAdapterModTest is Test {
    InitializeAdapterCaller caller;
    DispatchCaller dispatcher;
    PoolKey testKey;

    function setUp() public {
        caller = new InitializeAdapterCaller();
        dispatcher = new DispatchCaller();
        testKey = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0xBBBB))
        });
    }

    function test_initializeAdapter_writes_all_fields() public {
        caller.doInit(V4_ADAPTER_SLOT, address(0xAAAA), IHooks(address(0xBBBB)), testKey, false);
        (address ps, address fci, uint24 fee, bool reactive) = caller.readAdapter(V4_ADAPTER_SLOT);
        assertEq(ps, address(0xAAAA));
        assertEq(fci, address(0xBBBB));
        assertEq(fee, 3000);
        assertFalse(reactive);
    }

    function test_initializeAdapter_v3_reactive() public {
        caller.doInit(V3_ADAPTER_SLOT, address(0xCCCC), IHooks(address(0xDDDD)), testKey, true);
        (address ps, address fci, uint24 fee, bool reactive) = caller.readAdapter(V3_ADAPTER_SLOT);
        assertEq(ps, address(0xCCCC));
        assertEq(fci, address(0xDDDD));
        assertTrue(reactive);
    }

    function test_initializeAdapter_slots_isolated() public {
        caller.doInit(V4_ADAPTER_SLOT, address(0x1111), IHooks(address(0x2222)), testKey, false);
        caller.doInit(V3_ADAPTER_SLOT, address(0x3333), IHooks(address(0x4444)), testKey, true);
        (address ps4,,,) = caller.readAdapter(V4_ADAPTER_SLOT);
        (address ps3,,,) = caller.readAdapter(V3_ADAPTER_SLOT);
        assertEq(ps4, address(0x1111));
        assertEq(ps3, address(0x3333));
    }

    /// @dev Core dispatch test: V4 hookData (empty) routes to fciStorage(),
    /// V3 reactive hookData (0x03) routes to reactiveFciStorage().
    /// Verifies fciStorageFor() centralization produces same behavior as old inline ternaries.
    function test_fciStorageFor_dispatch_v4_vs_v3() public {
        PoolId poolId = PoolId.wrap(keccak256("test-pool"));

        // V4 hookData: empty bytes → routes to fciStorage()
        bytes memory v4HookData = "";
        dispatcher.doIncrementPosCount(v4HookData, poolId);

        // V3 reactive hookData: first byte = 0x03 (REACTIVE_FLAG | V3_FLAG)
        bytes memory v3HookData = abi.encodePacked(uint8(0x03));
        dispatcher.doIncrementPosCount(v3HookData, poolId);

        // Read both storage slots from dispatcher's context (storage writes happen there).
        // fciStorage() should have posCount = 1, reactiveFciStorage() should have posCount = 1.
        // If dispatch were broken, one would have 2 and the other 0.
        assertEq(dispatcher.readV4PosCount(poolId), 1, "V4 hookData should route to fciStorage");
        assertEq(dispatcher.readV3PosCount(poolId), 1, "V3 hookData should route to reactiveFciStorage");
    }
}
