// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

uint128 constant WAD_128 = 1e18;
uint128 constant RAY_128 = 1e27;

uint256 constant WAD_256 = 1e18;
uint256 constant RAY_256 = 1e27;
uint256 constant RAD_256 = 1e45;

function min(uint128 x, uint128 y) pure returns (uint128 z) {
    z = x <= y ? x : y;
}

function max(uint128 x, uint128 y) pure returns (uint128 z) {
    z = x >= y ? x : y;
}

function u64(uint256 x) pure returns (uint64 z) {
    require(x <= type(uint64).max, "x > u64 max");
    z = uint64(x);
}

function u128(uint256 x) pure returns (uint128 z) {
    require(x <= type(uint128).max, "x > u128 max");
    z = uint128(x);
}

function mul(uint128 x, uint128 y) pure returns (uint256 z) {
    z = uint256(x) * uint256(y);
}

function muldiv(uint128 x, uint128 y, uint128 d) pure returns (uint128 z) {
    z = u128(uint256(x) * uint256(y) / uint256(d));
}

// Binomial expansion
// (1+x)^n = 1+n*x+(n*(n-1)/2)*x^2+[n*(n-1)*(n-2)/6*x^3...
// TODO: check math
// TODO: fix overflows
function pow(uint128 x, uint128 n) pure returns (uint128 z) {
    z = RAY_128 + n * x + n * (n - 1) / 2 * x * x / RAY_128 + n * (n - 1)
        * (n - 2) / 6 * x * x / RAY_128 * x / RAY_128;
}

