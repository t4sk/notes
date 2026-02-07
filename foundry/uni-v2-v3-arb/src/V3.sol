// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./interfaces/IERC20.sol";
import {IPool} from "./interfaces/IPool.sol";
import {IUniswapV3Pool} from "./interfaces/uni-v3/IUniswapV3Pool.sol";
import {
    IUniswapV3SwapCallback
} from "./interfaces/uni-v3/IUniswapV3SwapCallback.sol";
import {TickMath} from "./lib/TickMath.sol";
import {TickLiquidity} from "./lib/TickLiquidity.sol";

contract V3 is IUniswapV3SwapCallback, IPool {
    address immutable public pool;

    constructor(address _pool) {
        pool = _pool;
    }

    function getFee() external view returns (uint256) {
        // 1e6
        return IUniswapV3Pool(pool).fee() * 1e12;
    }

    function getCurrentTick() external view returns (int24) {
        return IUniswapV3Pool(pool).slot0().tick;
    }

    function getCurrentLiquidity() external view returns (uint128) {
        return IUniswapV3Pool(pool).liquidity();
    }

    function getLiquidityRange(int24 tick, bool lte)
        external
        view
        returns (int24 tickLo, int24 tickHi, int128 liquidityNet)
    {
        return TickLiquidity.findLiquidityRange(IUniswapV3Pool(pool), tick, lte);
    }

    function swap(
        uint256 amtIn,
        uint256 minAmtOut,
        bool zeroForOne
    ) external returns (uint256 amtOut) {
        (int256 amt0, int256 amt1) = IUniswapV3Pool(pool)
            .swap(
                msg.sender,
                zeroForOne,
                int256(amtIn),
                zeroForOne
                    ? TickMath.MIN_SQRT_RATIO + 1
                    : TickMath.MAX_SQRT_RATIO - 1,
                abi.encode(msg.sender)
            );

        amtOut = zeroForOne ? uint256(-amt1) : uint256(-amt0);
        require(amtOut >= minAmtOut, "out < min");
    }

    function uniswapV3SwapCallback(
        int256 delta0,
        int256 delta1,
        bytes calldata data
    ) external {
        (address payer) = abi.decode(data, (address));

        if (delta0 > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token0())
                .transferFrom(payer, msg.sender, uint256(delta0));
        }
        if (delta1 > 0) {
            IERC20(IUniswapV3Pool(msg.sender).token1())
                .transferFrom(payer, msg.sender, uint256(delta1));
        }
    }
}
