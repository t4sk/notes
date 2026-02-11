// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function pool() external view returns (address);
    function fee() external view returns (uint256);
    function tick() external view returns (int24);
    function liq() external view returns (uint128);
    function range(int24 tick, bool lte)
        external
        view
        returns (int24 tickLo, int24 tickHi, int128 liquidityNet);
    function swap(uint256 amtIn, uint256 minAmtOut, bool zeroForOne)
        external
        returns (uint256 amtOut);
}

