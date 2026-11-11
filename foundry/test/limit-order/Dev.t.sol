// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

import {Price} from "@src/limit-order/lib/Price.sol";

contract Dev is Test {
    function test() public {
        uint256 g0 = gasleft();
        // uint128 p = Price.calc(type(int24).max >> 5);
        uint128 p = Price.calc(type(int24).min >> 4);
        uint256 g1 = gasleft();

        console.log("p %e", p);
        // 5000 ~ 6000 gas
        console.log("gas", g0 - g1);
    }

    struct Bin {
        uint128 x;
        uint128 y;
        uint128 z;
    }

    Bin public bin = Bin({x: 1, y: 2, z: 3});

    function setUp() public {
        /*
        bin.x = 1;
        bin.y = 2;
        bin.z = 3;
        */
    }

    function test_struct() public {
        uint256 g0 = gasleft();
        uint128 x = bin.x;
        uint256 g1 = gasleft();
        uint128 y = bin.y;
        uint256 g2 = gasleft();
        uint128 z = bin.z;
        uint256 g3 = gasleft();

        console.log("x", x);
        console.log("y", y);
        console.log("z", z);

        console.log("x", g0 - g1);
        console.log("y", g1 - g2);
        console.log("z", g2 - g3);
    }
}
