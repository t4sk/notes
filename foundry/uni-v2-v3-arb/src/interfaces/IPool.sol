// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IPool {
    function getFee(address pool) external view returns (uint256);
    function getCurrentTick(address pool) external view returns (int24);
    function getLiquidityRange(address pool, int24 tick, bool lte)
        external
        view
        returns (int24 tickLo, int24 tickHi, int128 liquidityNet);
    function swap(
        address pool,
        uint256 amtIn,
        uint256 minAmtOut,
        bool zeroForOne
    ) external returns (uint256 amtOut);
}

