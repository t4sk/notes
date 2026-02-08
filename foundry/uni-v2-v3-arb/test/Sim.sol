// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {IERC20} from "../src/interfaces/IERC20.sol";
import {V2} from "../src/V2.sol";
import {V3} from "../src/V3.sol";
import {Math, Q96} from "../src/lib/Math.sol";
import {FullMath} from "../src/lib/FullMath.sol";
import {TickMath} from "../src/lib/TickMath.sol";
import {
    UNI_V3_POOL_USDC_WETH_500,
    UNI_V3_POOL_USDC_WETH_3000
} from "../src/Constants.sol";

// TODO:
// - Collect pool info: list of (tick lo, tick hi, liquidity)
// - Export pool info
// - Run python script
// - Cast python script results
// - swap v2, v3 <-> v2, v3
contract Sim is Test {
    address constant POOL_A = UNI_V3_POOL_USDC_WETH_500;
    address constant POOL_B = UNI_V3_POOL_USDC_WETH_3000;
    IPool pool_a;
    IPool pool_b;
    IERC20 token0;
    IERC20 token1;

    struct Liquidity {
        // lower tick
        int24 lo;
        // higher tick
        int24 hi;
        // liquidity net
        int128 net;
        // active liquidity
        uint128 liq;
    }

    Liquidity[] pool_a_liq;
    Liquidity[] pool_b_liq;

    function setUp() public {
        pool_a = IPool(address(new V3(POOL_A)));
        pool_b = IPool(address(new V3(POOL_B)));

        require(pool_a.token0() == pool_b.token0(), "token 0");
        require(pool_a.token1() == pool_b.token1(), "token 1");

        token0 = IERC20(pool_a.token0());
        token1 = IERC20(pool_a.token1());

        int24 tick_a = pool_a.getCurrentTick();
        int24 tick_b = pool_b.getCurrentTick();

        if (tick_b < tick_a) {
            (tick_a, tick_b) = (tick_b, tick_a);
            (pool_a, pool_b) = (pool_b, pool_a);
        }

        // TODO: swap to create arbitrage opportunity

        uint128 liq_a = pool_a.getCurrentLiquidity();
        uint128 liq_b = pool_b.getCurrentLiquidity();

        console.log("tick a:", tick_a);
        console.log("tick b:", tick_b);

        delete pool_a_liq;
        delete pool_b_liq;

        // Increase
        int128 liq = int128(liq_a);
        int24 tick = tick_a;
        while (tick <= tick_a + 1000) {
            (int24 lo, int24 hi, int128 net) =
                pool_a.getLiquidityRange(tick - 1, false);

            if (tick == tick_a) {
                // TODO: wat do when lo = tick
                require(liq >= 0, "liq < 0");
                pool_a_liq.push(
                    Liquidity({lo: tick, hi: lo, net: 0, liq: uint128(liq)})
                );
            }

            require(tick <= lo, "tick > lo");
            require(lo <= hi, "lo > hi");

            tick = hi;
            liq += net;

            // price
            // uint160 s = TickMath.getSqrtRatioAtTick(tick);
            // TODO: adjust token decimals
            // console.log("p:", 1e12 / (s / Q96 * s / Q96));

            require(liq >= 0, "liq < 0");
            pool_a_liq.push(
                Liquidity({lo: lo, hi: hi, net: net, liq: uint128(liq)})
            );
        }

        write(pool_a_liq, "./tmp/pool_a.json");
    }

    function write(Liquidity[] storage pool_liq, string memory path) internal {
        string memory json = "[";
        for (uint256 i = 0; i < pool_liq.length; i++) {
            string memory obj = "";
            obj = string.concat(obj, "{");
            obj = string.concat(obj, '"lo":', vm.toString(pool_liq[i].lo), ",");
            obj = string.concat(obj, '"hi":', vm.toString(pool_liq[i].hi), ",");
            obj =
                string.concat(obj, '"net":', vm.toString(pool_liq[i].net), ",");
            obj = string.concat(obj, '"liq":', vm.toString(pool_liq[i].liq));
            obj = string.concat(obj, "}");

            if (i < pool_liq.length - 1) {
                json = string.concat(json, obj, ",");
            } else {
                json = string.concat(json, obj);
            }
        }
        json = string.concat(json, "]");
        vm.writeJson(json, path);
    }

    function test() public {}
}

