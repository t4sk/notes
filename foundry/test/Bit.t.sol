// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {Bit} from "../src/Bit.sol";

contract BitTest is Test {
    function msb(uint256 x) internal pure returns (uint256 z) {
        require(x != 0, "zero");

        while (x > 1) {
            x >>= 1;
            z++;
        }
    }

    function lsb(uint256 x) internal pure returns (uint256 z) {
        require(x != 0, "zero");

        while ((x & 1) == 0) {
            x >>= 1;
            z++;
        }
    }

    function test_msb(uint256 x) public pure {
        x = bound(x, 1, type(uint256).max);
        assertEq(Bit.msb(x), msb(x));
    }

    function test_lsb(uint256 x) public pure {
        x = bound(x, 1, type(uint256).max);
        assertEq(Bit.lsb(x), lsb(x));
    }
}
