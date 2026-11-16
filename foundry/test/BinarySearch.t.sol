// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {BinarySearch} from "../src/BinarySearch.sol";

contract BinarySearchTest is Test {
    function test(uint256[] memory xs, uint256 i) public {
        if (xs.length == 0) {
            return;
        }

        xs = vm.sort(xs);
        i = bound(i, 0, xs.length - 1);
        uint256 x = xs[i];
        uint256 j = BinarySearch.search(xs, x);

        assertGt(j, 0);
        assertLe(j, xs.length);
        assertEq(xs[j - 1], x);
        if (j < xs.length) {
            assertGt(xs[j], x);
        }
    }
}
