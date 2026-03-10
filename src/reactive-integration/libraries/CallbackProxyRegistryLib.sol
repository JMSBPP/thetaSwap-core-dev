// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {CallbackProxy} from "../types/CallbackProxy.sol";

error UnsupportedChain(uint256 chainId);

// Mainnet
CallbackProxy constant ETHEREUM_PROXY = CallbackProxy.wrap(0x1D5267C1bb7D8bA68964dDF3990601BDB7902D76);
CallbackProxy constant ARBITRUM_PROXY = CallbackProxy.wrap(0x4730c58FDA9d78f60c987039aEaB7d261aAd942E);
CallbackProxy constant AVALANCHE_PROXY = CallbackProxy.wrap(0x934Ea75496562D4e83E80865c33dbA600644fCDa);
CallbackProxy constant BASE_PROXY = CallbackProxy.wrap(0x0D3E76De6bC44309083cAAFdB49A088B8a250947);
CallbackProxy constant BSC_PROXY = CallbackProxy.wrap(0xdb81A196A0dF9Ef974C9430495a09B6d535fAc48);
CallbackProxy constant HYPEREVM_PROXY = CallbackProxy.wrap(0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4);
CallbackProxy constant LINEA_PROXY = CallbackProxy.wrap(0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4);
CallbackProxy constant PLASMA_PROXY = CallbackProxy.wrap(0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4);
CallbackProxy constant REACTIVE_PROXY = CallbackProxy.wrap(0x0000000000000000000000000000000000fffFfF);
CallbackProxy constant SONIC_PROXY = CallbackProxy.wrap(0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4);
CallbackProxy constant UNICHAIN_PROXY = CallbackProxy.wrap(0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4);

// Testnet
CallbackProxy constant BASE_SEPOLIA_PROXY = CallbackProxy.wrap(0xa6eA49Ed671B8a4dfCDd34E36b7a75Ac79B8A5a6);
CallbackProxy constant ETHEREUM_SEPOLIA_PROXY = CallbackProxy.wrap(0xc9f36411C9897e7F959D99ffca2a0Ba7ee0D7bDA);
CallbackProxy constant LASNA_PROXY = CallbackProxy.wrap(0x0000000000000000000000000000000000fffFfF);
CallbackProxy constant UNICHAIN_SEPOLIA_PROXY = CallbackProxy.wrap(0x9299472A6399Fd1027ebF067571Eb3e3D7837FC4);

function getCallbackProxy(uint256 chainId) pure returns (CallbackProxy) {
    // Mainnet
    if (chainId == 1) return ETHEREUM_PROXY;
    if (chainId == 42161) return ARBITRUM_PROXY;
    if (chainId == 43114) return AVALANCHE_PROXY;
    if (chainId == 8453) return BASE_PROXY;
    if (chainId == 56) return BSC_PROXY;
    if (chainId == 999) return HYPEREVM_PROXY;
    if (chainId == 59144) return LINEA_PROXY;
    if (chainId == 9745) return PLASMA_PROXY;
    if (chainId == 1597) return REACTIVE_PROXY;
    if (chainId == 146) return SONIC_PROXY;
    if (chainId == 130) return UNICHAIN_PROXY;
    // Testnet
    if (chainId == 84532) return BASE_SEPOLIA_PROXY;
    if (chainId == 11155111) return ETHEREUM_SEPOLIA_PROXY;
    if (chainId == 5318007) return LASNA_PROXY;
    if (chainId == 1301) return UNICHAIN_SEPOLIA_PROXY;
    revert UnsupportedChain(chainId);
}
