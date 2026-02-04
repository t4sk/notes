// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IUniswapV3FlashCallback {
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}
