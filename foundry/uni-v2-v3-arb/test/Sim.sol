// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";

// TODO:
// - Collect pool info: list of (tick lo, tick hi, liquidity)
// - Export pool info
// - Run python script
// - Cast python script results
// - swap v2, v3 <-> v2, v3
contract Sim is Test {}

contract V2 {
    function getFee() external view returns (uint256) {}

    function getLiquidityRange(
        // Current tick
        int256 tick,
        // Ascending or descending
        bool asc
    )
        external
        view
        returns (int256 tickLo, int256 tickHi, uint256 liquidity)
    {}

    function swap(
        address pool,
        uint256 amountIn,
        uint256 minAmountOut,
        bool zeroForOne
    ) external returns (uint256 amountOut) {}
}

