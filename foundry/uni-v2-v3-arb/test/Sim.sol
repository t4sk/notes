// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";
import {IPool} from "../src/interfaces/IPool.sol";
import {V2} from "../src/V2.sol";
import {V3} from "../src/V3.sol";
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

    function setUp() public {
        pool_a = IPool(address(new V3(POOL_A)));
        pool_b = IPool(address(new V3(POOL_B)));

        int24 tick_a = pool_a.getCurrentTick();
        int24 tick_b = pool_b.getCurrentTick();

        uint128 liq_a = pool_a.getCurrentLiquidity();
        uint128 liq_b = pool_b.getCurrentLiquidity();

        console.log("tick", tick_a);
        console.log("liq", liq_a);
    }

    function test() public {
    }
}

