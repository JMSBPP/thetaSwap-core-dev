// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {
    ProtocolAdapterStorage,
    V4_ADAPTER_SLOT, V3_ADAPTER_SLOT,
    protocolAdapterStorage,
    v4AdapterStorage, v3AdapterStorage
} from "@protocol-adapter/storage/ProtocolAdapterStorage.sol";

contract ProtocolAdapterStorageTest is Test {
    /// @dev V4 and V3 slots are disjoint
    function test_slots_are_disjoint() public pure {
        assertTrue(V4_ADAPTER_SLOT != V3_ADAPTER_SLOT);
    }

    /// @dev Convenience aliases return same storage as parameterized accessor
    function test_v4_alias_matches_parameterized() public {
        ProtocolAdapterStorage storage a = v4AdapterStorage();
        ProtocolAdapterStorage storage b = protocolAdapterStorage(V4_ADAPTER_SLOT);
        a.protocolState = address(0xBEEF);
        assertEq(b.protocolState, address(0xBEEF));
    }

    function test_v3_alias_matches_parameterized() public {
        ProtocolAdapterStorage storage a = v3AdapterStorage();
        ProtocolAdapterStorage storage b = protocolAdapterStorage(V3_ADAPTER_SLOT);
        a.protocolState = address(0xCAFE);
        assertEq(b.protocolState, address(0xCAFE));
    }

    /// @dev V4 and V3 storage do not collide
    function test_v4_v3_storage_isolated() public {
        ProtocolAdapterStorage storage v4 = v4AdapterStorage();
        ProtocolAdapterStorage storage v3 = v3AdapterStorage();
        v4.protocolState = address(0x1111);
        v3.protocolState = address(0x2222);
        assertEq(v4.protocolState, address(0x1111));
        assertEq(v3.protocolState, address(0x2222));
    }

    /// @dev All struct fields are writable and readable
    function test_all_fields_roundtrip() public {
        ProtocolAdapterStorage storage $ = v4AdapterStorage();
        $.protocolState = address(0xAAAA);
        $.fciEntryPoint = IHooks(address(0xBBBB));
        $.poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0xBBBB))
        });
        $.reactive = true;

        assertEq($.protocolState, address(0xAAAA));
        assertEq(address($.fciEntryPoint), address(0xBBBB));
        assertEq($.poolKey.fee, 3000);
        assertTrue($.reactive);
    }
}
