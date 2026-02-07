// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IUniswapV3Pool} from "../interfaces/uni-v3/IUniswapV3Pool.sol";
import {TickBitmap} from "./TickBitmap.sol";

library TickLiquidity {
    // Find liquidity range that
    // lte -> tickLo < tickHi <= tick
    // !lte -> tick < tickLo < tickHi
    function findLiquidityRange(IUniswapV3Pool pool, int24 tick, bool lte)
        internal
        view
        returns (int24 tickLo, int24 tickHi, int128 liquidityNet)
    {
        int24 tickSpacing = pool.tickSpacing();

        int24 t0 = findInitializedTick(pool, tick, tickSpacing, lte);
        int24 next = lte ? t0 - tickSpacing : t0;
        int24 t1 = findInitializedTick(pool, next, tickSpacing, lte);

        if (lte) {
            tickLo = t1;
            tickHi = t0;
            require(tickHi <= tick, "tick hi > tick");
        } else {
            tickLo = t0;
            tickHi = t1;
            require(tick < tickLo, "tick lo <= tick");
        }

        require(tickLo < tickHi, "tick lo >= tick hi");

        // liquidityNet at tickLo = liquidity added when crossing upward
        IUniswapV3Pool.Tick memory tickInfo = pool.ticks(tickLo);
        return (tickLo, tickHi, tickInfo.liquidityNet);
    }

    function findInitializedTick(
        IUniswapV3Pool pool,
        int24 tick,
        int24 tickSpacing,
        bool lte
    ) internal view returns (int24) {
        uint256 i = 0;
        while (true) {
            require(i < 1000, "max loop");
            i++;

            (int24 next, bool initialized) = TickBitmap.nextInitializedTickWithinOneWord(
                pool, tick, tickSpacing, lte
            );

            if (initialized) return next;

            // Not found in this word, move to next word
            tick = lte ? next - tickSpacing : next + tickSpacing;
        }
    }
}
