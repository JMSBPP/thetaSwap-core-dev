// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {Accounts, initAccounts} from "../../../../script/types/Accounts.sol";

import {FeeConcentrationIndexBuilderScript} from
    "../../../../script/reactive-integration/FeeConcentrationIndexBuilder.s.sol";
import {FeeConcentrationIndex} from
    "../../../../src/fee-concentration-index/FeeConcentrationIndex.sol";
import {ReactiveHookAdapter} from
    "../../../../src/reactive-integration/adapters/uniswapV3/ReactiveHookAdapter.sol";
import {CallbackProxy} from
    "../../../../src/reactive-integration/types/CallbackProxy.sol";
import {getCallbackProxy} from
    "../../../../src/reactive-integration/libraries/CallbackProxyRegistryLib.sol";
import {ethSepoliaPoolManager} from "../../../../script/utils/Deployments.sol";

/// @title FCI Differential Test — V4 Native vs V3 Reactive
/// @notice Broadcasts identical scenarios through both the V4 FCI hook and the V3
///         reactive adapter, then asserts deltaPlus values converge.
///
/// Usage:
///   forge script FeeConcentrationIndexV4ReactiveV3DiffTest --sig "test_mild()" --broadcast --rpc-url sepolia
///   forge script FeeConcentrationIndexV4ReactiveV3DiffTest --sig "test_crowdout()" --broadcast --rpc-url sepolia
contract FeeConcentrationIndexV4ReactiveV3DiffTest is Script, Test {
    FeeConcentrationIndexBuilderScript internal builder;
    FeeConcentrationIndex internal fci;
    ReactiveHookAdapter internal adapter;

    Accounts internal accounts;

    function setUp() public {
        accounts = initAccounts(vm);

        // 1. Deploy FCI hook (CREATE2 with mined salt for valid hook address)
        fci = _deployFCIHook(accounts.deployer.privateKey, ethSepoliaPoolManager());

        // 2. Deploy adapter (uses CallbackProxyRegistryLib for proxy address)
        vm.broadcast(accounts.deployer.privateKey);
        adapter = _deployAdapter();

        // 3. Deploy ThetaSwapReactive on Lasna via FFI (cast send --create)
        address payable lasnaService = payable(0x0000000000000000000000000000000000fffFfF);
        _deployReactiveFFI(
            "ThetaSwapReactive.sol:ThetaSwapReactive",
            abi.encode(address(adapter), lasnaService),
            vm.envString("REACTIVE_RPC_URL"),
            vm.toString(accounts.deployer.privateKey)
        );

        // 4. Create builder and inject freshly deployed hook + adapter
        builder = new FeeConcentrationIndexBuilderScript();
        builder.setUp();
        builder.setDeployments(address(fci), address(adapter));
    }

    // ═══════════════════════════════════════════════════════════════
    //  Test cases
    // ═══════════════════════════════════════════════════════════════

    function test_mild() public {
        builder.buildMildV4();
        builder.buildMildV3();

        uint128 deltaPlusV4 = fci.getDeltaPlus(builder.v4PoolKey(), false);
        uint128 deltaPlusV3 = adapter.getDeltaPlus(builder.v3PoolKey(), true);

        console2.log("V4 deltaPlus =", uint256(deltaPlusV4));
        console2.log("V3 deltaPlus =", uint256(deltaPlusV3));
        assertEq(uint256(deltaPlusV3), uint256(deltaPlusV4), "mild: V3 != V4");
    }

    function test_crowdout() public {
        builder.buildCrowdoutPhase1V4();
        builder.buildCrowdoutPhase2V4();
        builder.buildCrowdoutPhase3V4();

        builder.buildCrowdoutPhase1V3();
        builder.buildCrowdoutPhase2V3();
        builder.buildCrowdoutPhase3V3();

        uint128 deltaPlusV4 = fci.getDeltaPlus(builder.v4PoolKey(), false);
        uint128 deltaPlusV3 = adapter.getDeltaPlus(builder.v3PoolKey(), true);

        console2.log("V4 deltaPlus =", uint256(deltaPlusV4));
        console2.log("V3 deltaPlus =", uint256(deltaPlusV3));
        assertEq(uint256(deltaPlusV3), uint256(deltaPlusV4), "crowdout: V3 != V4");
    }

    // ═══════════════════════════════════════════════════════════════
    //  Deployment helpers
    // ═══════════════════════════════════════════════════════════════

    // Forge routes `new X{salt}()` through this factory under vm.broadcast
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function _deployFCIHook(uint256 deployerPK, address poolManager) internal returns (FeeConcentrationIndex) {
        uint160 flags = uint160(
            Hooks.AFTER_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_SWAP_FLAG
                | Hooks.AFTER_SWAP_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );

        bytes memory creationCode = type(FeeConcentrationIndex).creationCode;
        bytes memory constructorArgs = abi.encode(poolManager);

        (address hookAddress, bytes32 salt) =
            _findHookSalt(CREATE2_DEPLOYER, flags, creationCode, constructorArgs);

        vm.broadcast(deployerPK);
        FeeConcentrationIndex hook = new FeeConcentrationIndex{salt: salt}(poolManager);
        require(address(hook) == hookAddress, "hook address mismatch");
        return hook;
    }

    // ── Inlined HookMiner (avoids address(this) issues in forge script) ──

    uint160 constant FLAG_MASK = Hooks.ALL_HOOK_MASK;
    uint256 constant MAX_LOOP = 160_444;

    function _findHookSalt(
        address deployer_,
        uint160 flags,
        bytes memory creationCode,
        bytes memory constructorArgs
    ) internal view returns (address hookAddress, bytes32 salt) {
        flags = flags & FLAG_MASK;
        bytes32 initCodeHash = keccak256(abi.encodePacked(creationCode, constructorArgs));

        for (uint256 s; s < MAX_LOOP; s++) {
            hookAddress = address(
                uint160(
                    uint256(
                        keccak256(
                            abi.encodePacked(bytes1(0xFF), deployer_, bytes32(s), initCodeHash)
                        )
                    )
                )
            );
            if (uint160(hookAddress) & FLAG_MASK == flags && hookAddress.code.length == 0) {
                return (hookAddress, bytes32(s));
            }
        }
        revert("HookMiner: could not find salt");
    }

    function _deployAdapter() internal returns (ReactiveHookAdapter) {
        CallbackProxy proxy = getCallbackProxy(block.chainid);
        return new ReactiveHookAdapter{value: 0}(CallbackProxy.unwrap(proxy));
    }

    function _deployReactiveFFI(
        string memory contractPath,
        bytes memory constructorArgs,
        string memory rpcUrl,
        string memory privateKey
    ) internal returns (address deployed, bytes32 txHash) {
        string[] memory cmd = new string[](11);
        cmd[0] = "cast";
        cmd[1] = "send";
        cmd[2] = "--create";
        cmd[3] = vm.toString(abi.encodePacked(vm.getCode(contractPath), constructorArgs));
        cmd[4] = "--rpc-url";
        cmd[5] = rpcUrl;
        cmd[6] = "--private-key";
        cmd[7] = privateKey;
        cmd[8] = "--value";
        cmd[9] = "0.1ether";
        cmd[10] = "--json";

        bytes memory result = vm.ffi(cmd);
        string memory json = string(result);

        deployed = abi.decode(vm.parseJson(json, ".contractAddress"), (address));
        txHash = abi.decode(vm.parseJson(json, ".transactionHash"), (bytes32));

        string memory outJson = string.concat(
            '{"address":"', vm.toString(deployed),
            '","txHash":"', vm.toString(txHash), '"}'
        );
        vm.writeFile("broadcast/reactive-deploy.json", outJson);
    }
}
