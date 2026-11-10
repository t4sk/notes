// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {u128, mul, RAY_128} from "./Math.sol";

// TODO: test
// Liquidity shares math
library Liq {
    // Vault math
    // v = amount of value to deposit or withdraw
    // p = total value of the pool
    // s = shares to mint
    // t = total shares

    // (p + v) / p = (t + s) / t
    // v / p = s / t
    // s = v / p * t (p > 0)
    // v = s / t * p (t > 0)

    // off = virtual shares offset (1 unit of liquidity = 10**off shares)

    function shares(uint128 v, uint128 p, uint128 t, uint128 off)
        internal
        pure
        returns (uint128 s)
    {
        // + 10**off to virtual shares
        // + 1 to virtual token balance
        // TODO: check overflow
        s = v * (t + uint128(10 ** off)) / (p + 1);
    }

    function val(uint128 s, uint128 t, uint128 p, uint128 off)
        internal
        pure
        returns (uint128 v)
    {
        // TODO: check overflow
        v = s * (p + 1) / (t + uint128(10 ** off));
    }

    // Calculate liquidity p*x + y [1e27]
    function calc(uint128 p, uint128 x, uint128 y)
        internal
        pure
        returns (uint128 l)
    {
        // TODO: uint128 or uint256?
        l = u128(mul(p, x) + mul(y, RAY_128));
    }
}
