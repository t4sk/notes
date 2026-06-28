// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// TODO: ROCQ

// T[i] = total deposit at time i
// Q[i] = deposit deducted at time i
// D[i] = user's deposit after deduction at time i
//      = D[i - 1] - Q[i] * D[i - 1] / T[i - 1]

// User deposits at time K < N
// D[N] = D[K] * P[N] / P[K]

// P[0] = 1
// P[N] = prod(1 - Q[i] / T[i - 1]) for 1 <= i <= N

// B[i] = token bought at time i
// V[N] = user's claim on token bought up to time N
//      = B[K + 1] * D[K] / T[K] + ... + B[N] * D[N - 1] / T[N - 1]
//      = D[K] * (S[N] - S[K]) / P[K]

// S[0] = 0
// S[N] = sum(B[i] / T[i - 1] * P[i - 1]) for 1 <= i <= N

// M = u128 max
// R[N] = reduction factor at time N
// R[0] = 0
// R[N] = M - (M - R[N - 1]) * (1 - Q[N] / T[N - 1])
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
    function u128(uint256 u) internal pure returns (uint128) {
        require(u <= type(uint128).max, "u > u128 max");
        return uint128(u);
    }

    function min(uint128 x, uint128 y) internal pure returns (uint128 z) {
        z = x <= y ? x : y;
    }

    // M * S[N + 1]
    function ms(uint256 msn, uint128 b, uint128 rn, uint256 t)
        internal
        pure
        returns (uint256)
    {
        // TODO: overflow? use muldiv?
        return msn + b * (M - rn) / t;
    }

    // M * G[N + 1]
    function mg(uint256 mgn, uint128 y, uint128 rn, uint256 t)
        internal
        pure
        returns (uint256)
    {
        // TODO: overflow? use muldiv?
        return mgn + y * (M - rn) / t;
    }

    // R[N + 1]
    function r(uint256 rn, uint256 q, uint256 t)
        internal
        pure
        returns (uint128)
    {
        // TODO: overflow?
        // TODO: t = 0?
        return u128(M - (M - rn) * (t - q) / t);
    }

    // D[N + 1]
    function d(uint256 dk, uint256 rn, uint256 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: M - rk = 0?
        return u128(dk * (M - rn) / (M - rk));
    }

    // V[N + 1]
    function v(uint256 dk, uint256 msn, uint256 msk, uint256 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: use muldiv
        // TODO: M - rk = 0?
        return u128(dk * (msn - msk) / (M - rk));
    }

    // W[N + 1]
    function w(uint256 dk, uint256 mgn, uint256 mgk, uint256 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: use muldiv
        // TODO: M - rk = 0?
        return u128(dk * (mgn - mgk) / (M - rk));
    }

    function muldiv(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256)
    {
        // TODO:
        return x * y / d;
    }
}

