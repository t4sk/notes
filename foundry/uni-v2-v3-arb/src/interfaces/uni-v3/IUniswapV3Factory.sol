// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IUniswapV3Factory {
    function getPool(address tokenA, address tokenB, uint24 fee)
        external
        view
        returns (address pool);

    function createPool(address tokenA, address tokenB, uint24 fee)
        external
        returns (address pool);
}
