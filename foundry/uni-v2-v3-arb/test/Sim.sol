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
    UNI_V2_PAIR_USDC_WETH,
    UNI_V3_POOL_USDC_WETH_500,
    UNI_V3_POOL_USDC_WETH_3000
} from "../src/Constants.sol";

/*
forge test --fork-url $FORK_URL --ffi --match-path test/Sim.sol -vvv

Export data to python notebook
cp -R ./tmp/*.json ../../python/uniswap-v3/arb/tmp/
*/

contract Sim is Test {
    // address constant POOL_A = UNI_V2_PAIR_USDC_WETH;
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

    // Swap inside setUp to spread price differences
    bool constant SWAP = true;

    function setUp() public {
        // pool_a = IPool(address(new V2(POOL_A)));
        pool_a = IPool(address(new V3(POOL_A)));
        pool_b = IPool(address(new V3(POOL_B)));

        require(pool_a.token0() == pool_b.token0(), "token 0");
        require(pool_a.token1() == pool_b.token1(), "token 1");

        // Tokens
        token0 = IERC20(pool_a.token0());
        token1 = IERC20(pool_a.token1());

        uint256 dec0 = uint256(token0.decimals());
        uint256 dec1 = uint256(token1.decimals());

        deal(address(token0), address(this), 1e6 * 10 ** dec0);
        deal(address(token1), address(this), 1e6 * 10 ** dec1);

        token0.approve(address(pool_a), type(uint256).max);
        token0.approve(address(pool_b), type(uint256).max);
        token1.approve(address(pool_a), type(uint256).max);
        token1.approve(address(pool_b), type(uint256).max);

        // Ticks
        int24 tick_a = pool_a.tick();
        int24 tick_b = pool_b.tick();

        if (tick_b < tick_a) {
            (tick_a, tick_b) = (tick_b, tick_a);
            (pool_a, pool_b) = (pool_b, pool_a);
        }

        if (SWAP) {
            // tick_a < tick_b
            // Decrease tick_a -> swap X -> Y
            pool_a.swap({amtIn: 1e6 * 1e6, minAmtOut: 1, zeroForOne: true});
            // Increase tick_b -> swap Y -> X
            pool_b.swap({amtIn: 10 * 1e18, minAmtOut: 1, zeroForOne: false});

            tick_a = pool_a.tick();
            tick_b = pool_b.tick();
        }

        uint128 liq_a = pool_a.liq();
        uint128 liq_b = pool_b.liq();

        console.log("=== pools ===");
        console.log("token 0:", address(token0));
        console.log("token 1:", address(token1));
        console.log("pool a:", address(pool_a));
        console.log("pool b:", address(pool_b));
        console.log("tick a:", tick_a);
        console.log("tick b:", tick_b);
        console.log("liquidity a: %e", liq_a);
        console.log("liquidity b: %e", liq_b);
        console.log("fee a:", pool_a.fee());
        console.log("fee b:", pool_b.fee());

        // Collect data
        delete pool_a_liq;
        delete pool_b_liq;

        get(pool_a, pool_a_liq, liq_a, tick_a, tick_b, true);
        write(pool_a_liq, "./tmp/pool_a.json");

        get(pool_b, pool_b_liq, liq_b, tick_a, tick_b, false);
        write(pool_b_liq, "./tmp/pool_b.json");
    }

    // TODO: test on v2 pools
    function get(
        IPool pool,
        Liquidity[] storage pool_liq,
        uint128 curr_liq,
        int24 min_tick,
        int24 max_tick,
        bool asc
    ) internal {
        require(pool_liq.length == 0, "pool not empty");
        require(min_tick < max_tick, "min tick > max tick");

        if (asc) {
            int128 liq = int128(curr_liq);
            int24 tick = min_tick;

            while (tick <= max_tick) {
                (int24 lo, int24 hi, int128 net) =
                    pool.range({tick: tick - 1, lte: false});

                if (tick == min_tick && tick < lo) {
                    // Add current liquidity up to tick lo
                    pool_liq.push(
                        Liquidity({lo: tick, hi: lo, net: 0, liq: uint128(liq)})
                    );
                }

                require(tick <= lo, "tick > lo");
                require(lo <= hi, "lo > hi");

                tick = hi;
                liq += net;

                require(liq >= 0, "liq < 0");
                pool_liq.push(
                    Liquidity({lo: lo, hi: hi, net: net, liq: uint128(liq)})
                );
            }
        } else {
            int128 liq = int128(curr_liq);
            int24 tick = max_tick;

            while (min_tick <= tick) {
                (int24 lo, int24 hi, int128 net) =
                    pool.range({tick: tick, lte: true});

                if (tick == max_tick && hi < tick) {
                    // Add current liquidity up to tick hi
                    pool_liq.push(
                        Liquidity({lo: hi, hi: tick, net: 0, liq: uint128(liq)})
                    );
                }

                require(hi <= tick, "tick < hi");
                require(lo <= hi, "lo > hi");

                tick = lo;
                liq += net;

                require(liq >= 0, "liq < 0");
                pool_liq.push(
                    Liquidity({lo: lo, hi: hi, net: net, liq: uint128(liq)})
                );
            }
        }
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
        console.log("JSON file saved to", path);
    }

    function test() public {
        string[] memory cmd = new string[](5);
        cmd[0] = "py/arb/main.py";
        cmd[1] = "tmp/pool_a.json";
        cmd[2] = "tmp/pool_b.json";
        cmd[3] = vm.toString(pool_a.fee());
        cmd[4] = vm.toString(pool_b.fee());

        bytes memory res = vm.ffi(cmd);

        (uint256 dya, uint256 dyb, uint256 ta, uint256 tb) =
            abi.decode(res, (uint256, uint256, uint256, uint256));

        dya /= 1e18;
        dyb /= 1e18;
        int24 tick_a = int24(uint24(ta));
        int24 tick_b = int24(uint24(tb));

        console.log("=== py sim ===");
        console.log("dya: %e", dya);
        console.log("dyb: %e", dyb);
        console.log("diff: %e", (dyb - dya));
        console.log("tick a:", tick_a);
        console.log("tick b:", tick_b);

        if (dya > 0) {
            console.log("=== swap ===");
            uint256 dx = pool_a.swap(dya, 1, false);
            uint256 dy = pool_b.swap(dx, 1, true);

            console.log("dy: %e", dy);
            if (dy >= dya) {
                console.log("profit: %e", dy - dya);
            } else {
                console.log("loss: %e", dya - dy);
            }
        }
    }
}

