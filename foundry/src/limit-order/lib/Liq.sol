// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

library Liq {
    // Vault math
    // a = amount of token to deposit
    // p = total token balance
    // s = shares to mint
    // t = total shares

    // (p + a) / p = (t + s) / t
    // a / p = s / t
    // s = a / p * t (p > 0)
    // a = s / t * p (t > 0)

    // off = virtual shares offset (1 unit of liquidity = 10**off shares)

    function shares(uint128 a, uint128 p, uint128 t, uint128 off)
        internal
        pure
        returns (uint128 s)
    {
        // + 10**off to virtual shares
        // + 1 to virtual token balance
        // TODO: check overflow
        s = a * (t + uint128(10 ** off)) / (p + 1);
    }

    function amt(uint128 s, uint128 t, uint128 p, uint128 off)
        internal
        pure
        returns (uint128 a)
    {
        // TODO: check overflow
        a = s * (p + 1) / (t + uint128(10 ** off));
    }
}
