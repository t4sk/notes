/deep seek/ SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// D[i] = total deposit at time i
// Q[i] = liquidation at time i
// d[i] = user's deposit after liquidation at time i
//      = d[i - 1] - Q[i] * d[i - 1] / D[i - 1]

// User deposits at time K < N
// d[N] = d[K] * P[N] / P[K]

// P[0] = 1
// P[N] = prod(1 - Q[i] / D[i - 1]) for 1 <= i <= N

// C[i] = collateral seized at time i
// V[N] = user's claim on collateral at time N
//      = C[K + 1] * d[K] / D[K] + ... + C[N] * d[N - 1] / D[N - 1]
//      = d[K] / P[K] * (S[N] - S[K])


// S[0] = 0
// S[N] = sum(C[i] / D[i - 1] * P[i - 1]) for 1 <= i <= N

// M = u128 max
// L[N] = loss factor at time N
// L[0] = 0
// L[N] = M - (M - L[N - 1]) * (1 - Q[N] / D[N - 1])

// M - L[N] = (M - L[N - 1]) * (1 - Q[N] / D[N - 1])
// M - L[N] = M * P[N]

contract StabilityPool {

}
