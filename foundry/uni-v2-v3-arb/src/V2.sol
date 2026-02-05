// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Pair} from "./interfaces/uni-v2/IUniswapV2Pair.sol";
import {Math} from "./lib/Math.sol";

contract V2 {
    function getFee() external view returns (uint256) {
        // 0.3%
        return 0.003 * 1e18;
    }

    function getLiquidityRange(address pool, int256 tick, bool asc)
        external
        view
        returns (int256 tickLo, int256 tickHi, uint256 liquidity)
    {
        (uint112 x, uint112 y,) = IUniswapV2Pair(pool).getReserves();

        tickLo = type(int256).min;
        tickHi = type(int256).max;
        liquidity = Math.sqrt(uint256(x) * uint256(y));
    }

    function swap(
        address pool,
        uint256 amtIn,
        uint256 minAmtOut,
        bool zeroForOne
    ) external returns (uint256 amtOut) {
        IUniswapV2Pair pair = IUniswapV2Pair(pool);

        (uint112 x, uint112 y,) = pair.getReserves();

        (uint256 resIn, uint256 resOut) =
            zeroForOne ? (uint256(x), uint256(y)) : (uint256(y), uint256(x));

        uint256 amtInWithFee = amtIn * 997;
        amtOut = (amtInWithFee * resOut) / (resIn * 1000 + amtInWithFee);

        require(amtOut >= minAmtOut, "out < min");

        address tokenIn = zeroForOne ? pair.token0() : pair.token1();
        IERC20(tokenIn).transferFrom(msg.sender, pool, amtIn);

        (uint256 amt0Out, uint256 amt1Out) =
            zeroForOne ? (uint256(0), amtOut) : (amtOut, uint256(0));

        pair.swap(amt0Out, amt1Out, msg.sender, bytes(""));
    }
}

