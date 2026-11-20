// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

library BinarySearch {
    // Returns first index i such that x < xs[i]
    // Returns i = xs.length if no such index exists (xs[i] <= x for all i)
    // xs[] must be sorted ascending (duplicates allowed)
    function search(uint256[] memory xs, uint256 x)
        internal
        pure
        returns (uint256)
    {
        uint256 lo = 0;
        uint256 hi = xs.length;

        while (lo < hi) {
            // Invariant
            // (0) lo <= mid < hi -> mid + 1 <= hi
            uint256 mid = (lo + hi) / 2;
            if (x < xs[mid]) {
                // x < xs[i] for all i >= mid
                hi = mid;
                // Setting hi = mid, invariant becomes
                // (1) x < xs[i] for all i >= hi
            } else {
                // xs[i] <= x for all i <= mid
                lo = mid + 1;
                // Setting lo = mid + 1, invariant becomes
                // (2) xs[i] <= x for all i < lo
            }
        }
        // Invariants (1) and (2) hold before each iteration of the while loop

        // Loop exit condition: lo >= hi
        // and invariant (0):   lo <= hi
        // therefore lo = hi <= xs.length
        assert(lo == hi);

        // Rewrite invariants (1) and (2)
        // (1) x < xs[i] for all i >= lo
        // (2) xs[i] <= x for all i < lo

        // If lo == xs.length
        // (1) -> {i: i >= lo} = empty set, no i >= lo
        // (2) -> xs[i] <= x for all i

        // If lo < xs.length
        // (1) -> x < xs[lo]
        // (2) -> lo is the first index with x < xs[lo]

        return lo;
    }
}
