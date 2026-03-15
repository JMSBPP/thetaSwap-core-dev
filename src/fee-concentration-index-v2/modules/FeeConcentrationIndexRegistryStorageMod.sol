// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct FeeConcentrationIndexRegistryStorage {
    mapping(bytes1 => address) protocolFacets;
}

bytes32 constant FCI_REGISTRY_SLOT = keccak256("thetaSwap.fci.registry");

function fciRegistryStorage() pure returns (FeeConcentrationIndexRegistryStorage storage $) {
    bytes32 slot = FCI_REGISTRY_SLOT;
    assembly ("memory-safe") { $.slot := slot }
}
