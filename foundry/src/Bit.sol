// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

library Bit {
    function msb(uint256 x) internal pure returns (uint8 z) {
        require(x > 0, "x = 0");
        // clz(x) = Number of leading 0s in x, 256 if x = 0
        assembly {
            z := sub(255, clz(x))
        }
    }

    function lsb(uint256 x) internal pure returns (uint8 z) {
        require(x > 0, "x = 0");
        // Why -x = ~x + 1
        // x & ~x = all 1s = 2^256 - 1
        // 2^256 = 0
        // -x = ~x + 1

        // Why lsb = x & (~x + 1) = x & -x
        //  x     = 110100
        // ~x     = 001011 (negate x, least significant bit of x is now 0, all lower bits = 1)
        // ~x + 1 = 001100 (move from least to most significant bit of ~x, flip all 1 to 0, flip first 0 to 1, stop)
        //              LEFT             | LSB      | RIGHT
        // ~x + 1 = opposite of x's bits | 1 at lsb | all 0s
        // x & (~x + 1)
        // LEFT = AND x's bits and its opposite = 0s
        // LSB = both x and (~x + 1) = 1
        // RIGHT = (~x + 1) is all 0s = 0s
        assembly {
            // x & -x
            z := sub(255, clz(and(x, sub(0, x))))
        }
    }
}
