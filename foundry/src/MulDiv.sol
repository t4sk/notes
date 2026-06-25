// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// https://xn--2-umb.com/21/muldiv/

library Math {
    function mul512(uint256 x, uint256 y)
        internal
        pure
        returns (uint256 high, uint256 low)
    {
        // Uses Chinese Remainder Theorem to calculate x * y
        // x * y = high * 2^256 + low

        // https://xn--2-umb.com/17/chinese-remainder-theorem/
        // x0 = (x * y) mod 2^256
        // x1 = (x * y) mod (2^256 - 1)
        // low = x0
        // high = x1 - x0 - c, c = 1 if x1 < x0, else = 0
        assembly ("memory-safe") {
            // x1 = (x * y) mod (2^256 - 1)
            let mm := mulmod(x, y, not(0))
            // x0 = (x * y) mod 2^256
            low := mul(x, y)
            // x1 - x0 - c
            high := sub(sub(mm, low), lt(mm, low))
        }
    }

    function mulDiv(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);

            // 256 bits / 256 bits
            if (high == 0) {
                return low / d;
            }

            // Make sure the quotient is less than 2^256
            // (high * 2^256 + low) / d < 2^256
            // high + low / 2^256 < d
            // high + low / 2^256 < high + 1 <= d < d + 1
            // high < d
            require(high < d, "high >= denominator");

            // 512 bits / 256 bits

            // Explanations of steps 1 to 3 (in reverse order)
            // 3. Calculate x * y / d by finding the multiplicative inverse of d = d_inv
            // and return x * y * d_inv
            // 2. For d_inv to exist, d must be an odd number
            // 1. To calculate x * y / d correctly with d_inv, division must be exact (no remainder)

            // 1. Make division exact by subtracting the remainder from high and low

            // Why subtracting remainder doesn't change the quotient
            // If x * y / d = q with remainder r
            // then x * y = q * d + r, 0 <= r < d
            //      x * y / d = q + r / d
            // floor(x * y / d) = floor(q + r / d) = q (integer div makes r / d = 0)
            // (x * y - r) / d = q = floor(x * y / d)
            uint256 rem;
            assembly ("memory-safe") {
                // Compute remainder using mulmod.
                rem := mulmod(x, y, d)

                // Subtract 256 bit number from 512 bit number.
                high := sub(high, gt(rem, low))
                low := sub(low, rem)
            }

            // 2. Factor powers of two out of d and compute largest power of two divisor of d
            // Always >= 1. See https://cs.stackexchange.com/q/138556/92363.
            uint256 twos = d & (0 - d);
            assembly ("memory-safe") {
                // Divide d by twos.
                d := div(d, twos)

                // Divide [high low] by twos.
                low := div(low, twos)

                // Flip twos such that it is 2²⁵⁶ / twos. If twos is zero, then it becomes one.
                // 2^256 / 2^k
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from high into low.
            // Let 2^k = largest power of 2 divisor of d
            // low = high * 2^256 / 2^k + low / 2^k
            // - bits of high and low are both shifted to the right by k steps
            // - high * 2^256 / 2^k can overflow
            // - But overflow isn't a problem
            //   let z = high * 2^256 / 2^k + low / 2^k
            //   Reassign d = d / 2^k
            //   Regular division
            //     z / d = q
            //     so z = q * d
            //   Division by multiplicative inverse
            //     (z mod 2^256) * d_inv mod 2^256
            //   = ((q * d) mod 2^256) * d_inv mod 2^256
            //   =  (q * d * d_inv) mod 2^256
            //   = q mod 2^256
            low |= high * twos;

            // 3. Invert d mod 2²⁵⁶. Now that d is an odd number, it has an inverse modulo 2²⁵⁶ such
            // that d * inv ≡ 1 mod 2²⁵⁶. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, d * inv ≡ 1 mod 2⁴.
            uint256 inv = (3 * d) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also
            // works in modular arithmetic, doubling the correct bits in each step.
            inv *= 2 - d * inv; // inv mod 2⁸
            inv *= 2 - d * inv; // inv mod 2¹⁶
            inv *= 2 - d * inv; // inv mod 2³²
            inv *= 2 - d * inv; // inv mod 2⁶⁴
            inv *= 2 - d * inv; // inv mod 2¹²⁸
            inv *= 2 - d * inv; // inv mod 2²⁵⁶

            // Because the division is now exact we can divide by multiplying with the modular inv of d.
            // This will give us the correct result modulo 2²⁵⁶. Since the preconditions guarantee that the outcome is
            // less than 2²⁵⁶, this is the final result. We don't need to compute the high bits of the result and high
            // is no longer required.
            result = low * inv;
            return result;
        }
    }
}
