// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {RAY_128, min, muldiv} from "./Math.sol";

library Swap {
    function xy(uint128 x, uint128 y, uint128 p, uint128 fee, uint128 rem)
        internal
        pure
        returns (uint128 cin, uint128 cout, uint128 fin)
    {
        // x -> y
        // px = y -> max x = y / p
        // TODO: check bin.y * RAY / p <= u128
        // TODO: p > 0?
        uint128 max_cin = min(muldiv(y, RAY_128, p), x);
        uint128 max_fin = max_cin * fee / 1e5;

        if (rem >= max_cin + max_fin) {
            fin = max_fin;
            cin = max_cin;
        } else {
            fin = rem * fee / 1e5;
            cin = rem - fin;
        }

        // TODO: check round trip rounding errors
        // TODO: check p*cin/RAY_128 <= u128
        cout = min(muldiv(p, cin, RAY_128), y);
    }

    function yx(uint128 x, uint128 y, uint128 p, uint128 fee, uint128 rem)
        internal
        pure
        returns (uint128 cin, uint128 cout, uint128 fin)
    {
        // y -> x
        // px = y -> max y = px
        uint128 max_cin = min(muldiv(x, p, RAY_128), y);
        uint128 max_fin = max_cin * fee / 1e5;

        if (rem >= max_cin + max_fin) {
            fin = max_fin;
            cin = max_cin;
        } else {
            fin = rem * fee / 1e5;
            cin = rem - fin;
        }

        // TODO: check p*cin/RAY_128 <= u128
        // TODO: check p > 0?
        cout = min(muldiv(cin, RAY_128, p), x);
    }
}
