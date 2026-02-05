// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./interfaces/IERC20.sol";
import {IUniswapV3Pool} from "./interfaces/uni-v3/IUniswapV3Pool.sol";
import {
    IUniswapV3SwapCallback
} from "./interfaces/uni-v3/IUniswapV3SwapCallback.sol";
import {TickMath} from "./lib/TickMath.sol";
import {TickLiquidity} from "./lib/TickLiquidity.sol";

contract V3 is IUniswapV3SwapCallback {
    function getFee(address pool) external view returns (uint256) {
        // 1e6
        return IUniswapV3Pool(pool).fee() * 1e12;
    }

    function getLiquidityRange(address pool, int24 tick, bool asc)
        external
        view
        returns (int24 tickLo, int24 tickHi, uint256 liquidity)
    {
        IUniswapV3Pool pool = IUniswapV3Pool(pool);
        int24 tickSpacing = pool.tickSpacing();

        int24 compressed = tick / tickSpacing;
        // Round towards negative infinity
        if (tick < 0 && tick % tickSpacing != 0) compressed--;

        if (asc) {
            (tickLo, tickHi, liquidity) =
                TickLiquidity.findNextInitializedTickAbove(
                    pool, compressed, tickSpacing
                );
        } else {
            (tickLo, tickHi, liquidity) =
                TickLiquidity.findNextInitializedTickBelow(
                    pool, compressed, tickSpacing
                );
        }
    }

    function swap(
        address pool,
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
                abi.encode(pool, msg.sender)
            );

        amtOut = zeroForOne ? uint256(-amt1) : uint256(-amt0);
        require(amtOut >= minAmtOut, "out < min");
    }

    function uniswapV3SwapCallback(
        int256 delta0,
        int256 delta1,
        bytes calldata data
    ) external {
        (address pool, address payer) = abi.decode(data, (address, address));

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
