// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {RAY_256, u128, pow} from "./Math.sol";

uint256 constant B = 1.0001 * 1e27;

library Price {
    function calc(int24 t) internal pure returns (uint128 p) {
        p = t >= 0
            ? u128(pow(B, uint256(uint24(t)), RAY_256))
            : u128(RAY_256 * RAY_256 / pow(B, uint256(uint24(-t)), RAY_256));
    }
}
