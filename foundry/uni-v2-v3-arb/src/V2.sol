// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV2Pair} from "./interfaces/uni-v2/IUniswapV2Pair.sol";
import {IPool} from "./interfaces/IPool.sol";
import {Math, Q96} from "./lib/Math.sol";
import {FullMath} from "./lib/FullMath.sol";
import {TickMath} from "./lib/TickMath.sol";

contract V2 is IPool {
    address public immutable pool;
    IUniswapV2Pair public immutable pair;

    constructor(address _pool) {
        pool = _pool;
        pair = IUniswapV2Pair(pool);
    }

    function token0() external view returns (address) {
        return pair.token0();
    }

    function token1() external view returns (address) {
        return pair.token1();
    }

    function getFee() external view returns (uint256) {
        // 0.3%
        return 0.003 * 1e18;
    }

    function getCurrentTick() external view returns (int24) {
        (uint112 x, uint112 y,) = pair.getReserves();
        // sqrt(y / x) * Q96
        uint256 ratioX96 = FullMath.mulDiv(y, Q96, x);
        uint256 sqrtPriceX96 = Math.sqrt(ratioX96) << 48;
        require(sqrtPriceX96 <= type(uint160).max);
        return TickMath.getTickAtSqrtRatio(uint160(sqrtPriceX96));
    }

    function getCurrentLiquidity() external view returns (uint128) {
        (uint112 x, uint112 y,) = pair.getReserves();
        uint256 liquidity = Math.sqrt(uint256(x) * uint256(y));
        require(
            liquidity <= uint256(type(uint128).max), "liquidity > max uint128"
        );
        return uint128(liquidity);
    }

    function getLiquidityRange(int24 tick, bool lte)
        external
        view
        returns (int24 tickLo, int24 tickHi, int128 liquidityNet)
    {
        (uint112 x, uint112 y,) = pair.getReserves();

        // lte -> tickLo < tickHi <= tick
        // !lte -> tick < tickLo < tickHi
        if (lte) {
            tickLo = type(int24).min;
            tickHi = tick;
        } else {
            tickLo = tick + 1;
            tickHi = type(int24).max;
        }
        // Liquidity is constant
        liquidityNet = 0;
    }

    function swap(uint256 amtIn, uint256 minAmtOut, bool zeroForOne)
        external
        returns (uint256 amtOut)
    {
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

