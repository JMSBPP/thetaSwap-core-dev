// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

struct ChainAddresses {
    address poolManager;
    address positionManager;
    address stateView;
    address v4Quoter;
    address v3Factory;
    address permit2;
    address weth;
    address usdc;
    address usdt;
    address dai;
    address wbtc;
    uint256 forkBlock;
}

function getChainAddresses(string memory chainName) pure returns (ChainAddresses memory) {
    bytes32 h = keccak256(abi.encodePacked(chainName));

    if (h == keccak256("ethereum")) {
        return ChainAddresses({
            poolManager: 0x000000000004444c5dc75cB358380D2e3dE08A90,
            positionManager: 0xbD216513d74C8cf14cf4747E6AaA6420FF64ee9e,
            stateView: 0x7ffE42c4A5Deea5b0fec41Ee5a8E9cC2F7A7b263,
            v4Quoter: 0x52F0E24D1c21C8A0cB1e5a5dD6198556BD9E1203,
            v3Factory: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3,
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
            usdc: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
            usdt: 0xdAC17F958D2ee523a2206206994597C13D831ec7,
            dai: 0x6B175474E89094C44Da98b954EedeAC495271d0F,
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
            forkBlock: 21_000_000
        });
    }

    revert("ForkUtils: unknown chain");
}

function poolManager(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).poolManager;
}

function positionManager(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).positionManager;
}

function stateView(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).stateView;
}

function v4Quoter(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).v4Quoter;
}

function v3Factory(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).v3Factory;
}

function permit2(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).permit2;
}

function weth(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).weth;
}

function usdc(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).usdc;
}

function usdt(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).usdt;
}

function dai(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).dai;
}

function wbtc(string memory chainName) pure returns (address) {
    return getChainAddresses(chainName).wbtc;
}

function forkBlock(string memory chainName) pure returns (uint256) {
    return getChainAddresses(chainName).forkBlock;
}
