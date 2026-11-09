// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

uint128 constant RAY_128 = 1e27;
uint256 constant RAY_256 = 1e27;

function min(uint128 x, uint128 y) pure returns (uint128 z) {
    z = x <= y ? x : y;
}

function max(uint128 x, uint128 y) pure returns (uint128 z) {
    z = x >= y ? x : y;
}

function mul(uint128 x, uint128 y) pure returns (uint256 z) {
    z = uint256(x) * uint256(y);
}

function muldiv(uint128 x, uint128 y, uint128 d) pure returns (uint128 z) {
    z = u128(uint256(x) * uint256(y) / uint256(d));
}

function u128(uint256 x) pure returns (uint128 z) {
    require(x <= type(uint128).max, "x > u128 max");
    z = uint128(x);
}

// Returns b * (x / b)^n
// b = 1
function pow(uint256 x, uint256 n, uint256 b) pure returns (uint256 z) {
    assembly {
        switch x
        // x = 0
        case 0 {
            switch n
            // n = 0 --> x**n = 0**0 --> 1
            case 0 { z := b }
            // n > 0 --> x**n = 0**n --> 0
            default { z := 0 }
        }
        default {
            switch mod(n, 2)
            // x > 0 and n is even --> z = 1
            case 0 { z := b }
            // x > 0 and n is odd --> z = x
            default { z := x }

            let half := div(b, 2) // for rounding
            // n = n / 2, while n > 0, n = n / 2
            for { n := div(n, 2) } n { n := div(n, 2) } {
                let xx := mul(x, x)
                // Check overflow - revert if xx / x != x
                if iszero(eq(div(xx, x), x)) { revert(0, 0) }
                // Round (xx + half) / b
                let xxRound := add(xx, half)
                // Check overflow - revert if xxRound < xx
                if lt(xxRound, xx) { revert(0, 0) }
                x := div(xxRound, b)
                // if n % 2 == 1
                if mod(n, 2) {
                    let zx := mul(z, x)
                    // revert if x != 0 and zx / x != z
                    if and(iszero(iszero(x)), iszero(eq(div(zx, x), z))) {
                        revert(0, 0)
                    }
                    // Round (zx + half) / b
                    let zxRound := add(zx, half)
                    // Check overflow - revert if zxRound < zx
                    if lt(zxRound, zx) { revert(0, 0) }
                    z := div(zxRound, b)
                }
            }
        }
    }
}
