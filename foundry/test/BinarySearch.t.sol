// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {BinarySearch} from "@src/BinarySearch.sol";

contract BinarySearchTest is Test {
    function test_range(uint256[] memory xs, uint256 x) public {
        xs = vm.sort(xs);

        if (xs.length > 0) {
            x = bound(x, xs[0], xs[xs.length - 1]);
        }

        uint256 k = BinarySearch.search(xs, x);

        assertGe(k, 0);
        assertLe(k, xs.length);

        // (1) x < xs[i] for all i >= lo
        for (uint256 i = k; i < xs.length; i++) {
            assertGt(xs[i], x);
        }
        // (2) xs[i] <= x for all i < lo
        for (uint256 i = 0; i < k; i++) {
            assertLe(xs[i], x);
        }
    }
}
