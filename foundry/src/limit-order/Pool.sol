// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// Swap
// p*dx = dy

// p(i) = 1.0001^i
// X[i] = token X in tick i
// Y[i] = token Y in tick i
// L[i] = liquidity at tick i
//      = p(i) * X[i] + Y[i]

// c = current tick
// For i < c -> L[i] = Y[i]
// For c < i -> L[i] = p(i) * X[i]

contract Pool {
    function inc() external {}
    function dec() external {}
    function swap() external {}
}
