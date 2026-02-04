// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IUniswapV3SwapCallback {
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external;
}
