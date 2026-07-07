// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// T[i] = total deposit at time i                  (128 bits)
// Q[i] = deposit deducted at time i               (128 bits)
// D[i] = user's deposit after deduction at time i (128 bits)
//      = D[i - 1] - Q[i] * D[i - 1] / T[i - 1]

// User deposits at time K < N
// D[N] = D[K] * P[N] / P[K]

// P[0] = 1
// P[N] = prod(1 - Q[i] / T[i - 1]) for 1 <= i <= N (128 bits)
// P[N] <= 1 for all N

// B[i] = token bought at time i [128 bits]
// V[N] = user's claim on token bought up to time N
//      = B[K + 1] * D[K] / T[K] + ... + B[N] * D[N - 1] / T[N - 1]
//      = D[K] * (S[N] - S[K]) / P[K] [128 bits]

// S[0] = 0
// S[N] = sum(B[i] / T[i - 1] * P[i - 1]) for 1 <= i <= N (128 bits)

// M = u128 max
// R[N] = reduction factor at time N (128 bits)
// R[0] = 0
// R[N] = M - (M - R[N - 1]) * (1 - Q[N] / T[N - 1]) (128 bits)
//             128 bits        128 bits

// M - R[N] = (M - R[N - 1]) * (1 - Q[N] / T[N - 1])
// M - R[N] = M * P[N]

// M - R[N] <= 128 bits
// M * S[N] = sum(B[i] / T[i - 1] * (M - R[i - 1])) for 1 <= i <= N
// M * S[N] <= 256 bits

// D[N] = D[K] * P[N] / P[K]
//      = D[K] * (M - R[N]) / (M - R[K])
//      <= 256 bits

// V[N] = D[K] * (S[N] - S[K]) / P[K]
//      = D[K] * M * (S[N] - S[K]) / (M - R[K])
//      <= 128 + 256 bits
//
// Y[i] = yield gain at time i
// Same math as S[N], M * S[N] and V[N]
// G[0] = 0
// G[N] = sum(Y[i] / T[i - 1] * P[i - 1]) for 1 <= i <= N
// M * G[N] = sum(Y[i] / T[i - 1] * (M - R[i - 1])) for 1 <= i <= N
// W[N] = user's claim on yield gains up to time N
//      = D[K] * M * (G[N] - G[K]) / (M - R[K])

uint256 constant M = type(uint128).max;

library Math {
    function u128(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, "x > u128 max");
        return uint128(x);
    }

    function min(uint128 x, uint128 y) internal pure returns (uint128 z) {
        z = x <= y ? x : y;
    }

    function max(uint128 x, uint128 y) internal pure returns (uint128 z) {
        z = x >= y ? x : y;
    }

    function mul512(uint256 x, uint256 y)
        internal
        pure
        returns (uint256 high, uint256 low)
    {
        assembly ("memory-safe") {
            let mm := mulmod(x, y, not(0))
            low := mul(x, y)
            high := sub(sub(mm, low), lt(mm, low))
        }
    }

    function muldiv(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256 result)
    {
        unchecked {
            (uint256 high, uint256 low) = mul512(x, y);

            if (high == 0) {
                return low / d;
            }

            require(high < d, "high >= denominator");

            // 512 bits / 256 bits
            uint256 rem;
            assembly ("memory-safe") {
                rem := mulmod(x, y, d)
                high := sub(high, gt(rem, low))
                low := sub(low, rem)
            }

            uint256 twos = d & (0 - d);
            assembly ("memory-safe") {
                d := div(d, twos)
                low := div(low, twos)
                twos := add(div(sub(0, twos), twos), 1)
            }

            low |= high * twos;

            uint256 inv = (3 * d) ^ 2;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;
            inv *= 2 - d * inv;

            result = low * inv;
            return result;
        }
    }

    // M * S[N + 1]
    function ms(uint256 msn, uint128 b, uint128 rn, uint128 tn)
        internal
        pure
        returns (uint256)
    {
        return msn + muldiv(b, M - rn, tn);
    }

    // M * G[N + 1]
    function mg(uint256 mgn, uint128 y, uint128 rn, uint128 tn)
        internal
        pure
        returns (uint256)
    {
        return mgn + muldiv(y, (M - rn), tn);
    }

    // R[N + 1]
    function r(uint128 rn, uint128 q, uint128 tn)
        internal
        pure
        returns (uint128)
    {
        require(tn > 0, "tn = 0");
        return u128(muldiv(M - (M - rn), tn - q, tn));
    }

    // D[N]
    function d(uint128 dk, uint128 rn, uint128 rk)
        internal
        pure
        returns (uint128)
    {
        if (rk == M) {
            return 0;
        }
        return u128(muldiv(dk, M - rn, M - rk));
    }

    // V[N]
    function v(uint128 dk, uint256 msn, uint256 msk, uint128 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: M - rk = 0?
        if (rk == M) {
            return 0;
        }
        return u128(muldiv(dk, msn - msk, M - rk));
    }

    // W[N]
    function w(uint128 dk, uint256 mgn, uint256 mgk, uint128 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: M - rk = 0?
        if (rk == M) {
            return 0;
        }
        return u128(muldiv(dk, mgn - mgk, M - rk));
    }
}

