// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// Liquidity shares math
library Liq {
    // Vault math
    // a = amount of token to deposit or withdraw
    // b = total token balance
    // s = shares to mint
    // t = total shares

    // (b + a) / b = (t + s) / t
    // a / b = s / t
    // s = a / b * t (b > 0)
    // a = s / t * b (t > 0)

    // off = virtual shares offset (1 unit of liquidity = 10**off shares)

    function shares(uint128 a, uint128 b, uint128 t, uint128 off)
        internal
        pure
        returns (uint128 s)
    {
        // + 10**off to virtual shares
        // + 1 to virtual token balance
        // TODO: check overflow
        s = a * (t + uint128(10 ** off)) / (b + 1);
    }

    function amt(uint128 s, uint128 t, uint128 b, uint128 off)
        internal
        pure
        returns (uint128 a)
    {
        // TODO: check overflow
        a = s * (b + 1) / (t + uint128(10 ** off));
    }
}
