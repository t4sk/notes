// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

uint128 constant V = 1e18;
uint128 constant W = 1e36;

function u128(uint256 x) pure returns (uint128 z) {
    require(x <= type(uint128).max);
    z = uint128(x);
}

function mul(uint128 x, uint128 y) pure returns (uint256 z) {
    z = uint256(x) * uint256(y);
}

function muldiv(uint128 x, uint128 y, uint128 z) pure returns (uint128 q) {
    q = u128(uint256(x) * uint256(y) / uint256(z));
}
