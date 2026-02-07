// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IPool {
    function pool() external view returns (address);
    function getFee() external view returns (uint256);
    function getCurrentTick() external view returns (int24);
    function getCurrentLiquidity() external view returns (uint128);
    function getLiquidityRange(int24 tick, bool lte)
        external
        view
        returns (int24 tickLo, int24 tickHi, int128 liquidityNet);
    function swap(
        uint256 amtIn,
        uint256 minAmtOut,
        bool zeroForOne
    ) external returns (uint256 amtOut);
}

