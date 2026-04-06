// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import {
    NoteId,
    VANILLA,
    ACCRUAL_DECRUAL,
    InvalidRange,
    InvalidNotionalRatio
} from "@range-accrual-note/types/NoteId.sol";

/// @dev Helper to make validate() callable externally (vm.expectRevert needs external call)
contract NoteIdValidator {
    function validateExternal(NoteId id) external pure {
        id.validate();
    }
}

/// @dev BTT spec: test/range-accrual-note/trees/NoteId.tree
contract NoteIdTest is Test {
    NoteIdValidator validator;

    function setUp() public {
        validator = new NoteIdValidator();
    }

    // ── Helpers ──

    function _buildFullNoteId() internal pure returns (NoteId) {
        NoteId id = NoteId.wrap(0);
        id = id.addPoolIndex(0xABCDEF1234);
        id = id.addVegoid(42);
        id = id.addEpochLength(7200);
        id = id.addExtensionFlag(VANILLA);
        id = id.addNotionalRatio(10);
        id = id.addIsLong(1);
        id = id.addTokenType(0);
        id = id.addTickLower(int24(-887220));
        id = id.addTickUpper(int24(887220));
        id = id.addEpochId(uint40(1000));
        return id;
    }

    // ── given a freshly constructed NoteId / when all fields set ──

    function test_roundtrip_poolIndex() public pure {
        NoteId id = NoteId.wrap(0).addPoolIndex(0xABCDEF1234);
        assertEq(id.poolIndex(), 0xABCDEF1234);
    }

    function test_roundtrip_vegoid() public pure {
        NoteId id = NoteId.wrap(0).addVegoid(255);
        assertEq(id.vegoid(), 255);
    }

    function test_roundtrip_epochLength() public pure {
        NoteId id = NoteId.wrap(0).addEpochLength(7200);
        assertEq(id.epochLen(), 7200);
    }

    function test_roundtrip_extensionFlag() public pure {
        NoteId id = NoteId.wrap(0).addExtensionFlag(ACCRUAL_DECRUAL);
        assertEq(id.extensionFlag(), ACCRUAL_DECRUAL);
    }

    function test_roundtrip_notionalRatio() public pure {
        NoteId id = NoteId.wrap(0).addNotionalRatio(127); // max 7 bits
        assertEq(id.notionalRatio(), 127);
    }

    function test_roundtrip_isLong() public pure {
        NoteId id = NoteId.wrap(0).addIsLong(1);
        assertEq(id.isLong(), 1);

        NoteId id2 = NoteId.wrap(0).addIsLong(0);
        assertEq(id2.isLong(), 0);
    }

    function test_roundtrip_tokenType() public pure {
        NoteId id = NoteId.wrap(0).addTokenType(1);
        assertEq(id.tokenType(), 1);
    }

    function test_roundtrip_tickLower() public pure {
        NoteId id = NoteId.wrap(0).addTickLower(int24(-887220));
        assertEq(id.tickLower(), int24(-887220));
    }

    function test_roundtrip_tickUpper() public pure {
        NoteId id = NoteId.wrap(0).addTickUpper(int24(887220));
        assertEq(id.tickUpper(), int24(887220));
    }

    function test_roundtrip_epochId() public pure {
        NoteId id = NoteId.wrap(0).addEpochId(uint40(999999));
        assertEq(id.epochId(), uint40(999999));
    }

    // ── when fields are set independently / no corruption ──

    function test_adjacentFields_notCorrupted() public pure {
        NoteId id = _buildFullNoteId();

        // Verify every field survives when all are set
        assertEq(id.poolIndex(), 0xABCDEF1234);
        assertEq(id.vegoid(), 42);
        assertEq(id.epochLen(), 7200);
        assertEq(id.extensionFlag(), VANILLA);
        assertEq(id.notionalRatio(), 10);
        assertEq(id.isLong(), 1);
        assertEq(id.tokenType(), 0);
        assertEq(id.tickLower(), int24(-887220));
        assertEq(id.tickUpper(), int24(887220));
        assertEq(id.epochId(), uint40(1000));
    }

    // ── given tickLower >= tickUpper ──

    function test_RevertGiven_tickLowerEqTickUpper() public {
        NoteId id = NoteId.wrap(0)
            .addNotionalRatio(1)
            .addTickLower(int24(100))
            .addTickUpper(int24(100));

        vm.expectRevert(abi.encodeWithSelector(InvalidRange.selector, int24(100), int24(100)));
        validator.validateExternal(id);
    }

    function test_RevertGiven_tickLowerGtTickUpper() public {
        NoteId id = NoteId.wrap(0)
            .addNotionalRatio(1)
            .addTickLower(int24(200))
            .addTickUpper(int24(100));

        vm.expectRevert(abi.encodeWithSelector(InvalidRange.selector, int24(200), int24(100)));
        validator.validateExternal(id);
    }

    // ── given notionalRatio is zero ──

    function test_RevertGiven_zeroNotionalRatio() public {
        NoteId id = NoteId.wrap(0)
            .addNotionalRatio(0)
            .addTickLower(int24(-100))
            .addTickUpper(int24(100));

        vm.expectRevert(InvalidNotionalRatio.selector);
        validator.validateExternal(id);
    }

    // ── given valid parameters ──

    function test_validate_passes() public pure {
        NoteId id = _buildFullNoteId();
        id.validate(); // should not revert
    }

    // ── Fuzz: roundtrip all fields ──

    function testFuzz_roundtrip_allFields(
        uint64 _poolIndex,
        uint8 _vegoid,
        uint16 _epochLength,
        uint8 _extensionFlag,
        uint8 _notionalRatio,
        uint8 _isLong,
        uint8 _tokenType,
        int24 _tickLower,
        int24 _tickUpper,
        uint40 _epochId
    ) public pure {
        // Bound to valid bit widths
        _poolIndex = uint64(bound(uint256(_poolIndex), 0, (1 << 40) - 1));
        _extensionFlag = uint8(bound(uint256(_extensionFlag), 0, 7));
        _notionalRatio = uint8(bound(uint256(_notionalRatio), 0, 127));
        _isLong = uint8(bound(uint256(_isLong), 0, 1));
        _tokenType = uint8(bound(uint256(_tokenType), 0, 1));

        NoteId id = NoteId.wrap(0);
        id = id.addPoolIndex(_poolIndex);
        id = id.addVegoid(_vegoid);
        id = id.addEpochLength(_epochLength);
        id = id.addExtensionFlag(_extensionFlag);
        id = id.addNotionalRatio(_notionalRatio);
        id = id.addIsLong(_isLong);
        id = id.addTokenType(_tokenType);
        id = id.addTickLower(_tickLower);
        id = id.addTickUpper(_tickUpper);
        id = id.addEpochId(_epochId);

        assertEq(id.poolIndex(), _poolIndex);
        assertEq(id.vegoid(), _vegoid);
        assertEq(id.epochLen(), _epochLength);
        assertEq(id.extensionFlag(), _extensionFlag);
        assertEq(id.notionalRatio(), _notionalRatio);
        assertEq(id.isLong(), _isLong);
        assertEq(id.tokenType(), _tokenType);
        assertEq(id.tickLower(), _tickLower);
        assertEq(id.tickUpper(), _tickUpper);
        assertEq(id.epochId(), _epochId);
    }
}
