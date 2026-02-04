// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IUniswapV3MintCallback {
    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;
}
