// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

library BinarySearch {
    // Returns first index where xs[i] > x
    function search(uint256[] memory xs, uint256 x)
        internal
        pure
        returns (uint256 i)
    {
        uint256 lo = 0;
        uint256 hi = xs.length;

        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (x < xs[mid]) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }

        i = lo;
    }
}
