// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// T[i] = total deposit at time i
// Q[i] = deposit deducted at time i
// D[i] = user's deposit after deduction at time i
//      = D[i - 1] - Q[i] * D[i - 1] / T[i - 1]

// User deposits at time K < N
// D[N] = D[K] * P[N] / P[K]

// P[0] = 1
// P[N] = prod(1 - Q[i] / T[i - 1]) for 1 <= i <= N

// C[i] = collateral seized at time i
// V[N] = user's claim on collateral at time N
//      = C[K + 1] * D[K] / T[K] + ... + C[N] * D[N - 1] / T[N - 1]
//      = D[K] * (S[N] - S[K]) / P[K]

// S[0] = 0
// S[N] = sum(C[i] / T[i - 1] * P[i - 1]) for 1 <= i <= N

// M = u128 max
// R[N] = reduction factor at time N
// R[0] = 0
// R[N] = M - (M - R[N - 1]) * (1 - Q[N] / T[N - 1])
//             128 bits        128 bits

// M - R[N] = (M - R[N - 1]) * (1 - Q[N] / T[N - 1])
// M - R[N] = M * P[N]

// M - R[N] <= 128 bits
// M * S[N] = sum(C[i] / T[i - 1] * (M - R[i - 1])) for 1 <= i <= N
// M * S[N] <= 256 bits

// D[N] = D[K] * P[N] / P[K]
//      = D[K] * (M - R[N]) / (M - R[K])
//      <= 256 bits

// V[N] = D[K] * (S[N] - S[K]) / P[K]
//      = D[K] * M * (S[N] - S[K]) / (M - R[K])
//      <= 128 + 256 bits

uint256 constant M = type(uint128).max;

library Math {
    function u128(uint256 u) internal pure returns (uint256) {
        require(u <= type(uint128).max, "u > u128 max");
        return uint128(u);
    }

    function R(uint256 r, uint256 q, uint256 d)
        internal
        pure
        returns (uint256)
    {
        return M - (M - r) * (d - q) / d;
    }

    function D(uint256 dk, uint256 rn, uint256 rk)
        internal
        pure
        returns (uint256)
    {
        return dk * (M - rn) / (M - rk);
    }

    function V(uint256 dk, uint256 msn, uint256 msk, uint256 rk)
        internal
        pure
        returns (uint256)
    {
        return dk * (msn - msk) / (M - rk);
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

contract StabilityPool {
    // T[N]
    uint128 public T;
    // R[N]
    uint128 public R;
    // M * S[N]
    uint256 public MS;

    struct Snapshot {
        uint128 dk;
        uint128 rk;
        uint256 msk;
    }

    mapping(address => Snapshot) public snapshots;

    function deposit() external {}

    function withdraw() external {}

    function claim() external {}

    function swap() external {}
}
