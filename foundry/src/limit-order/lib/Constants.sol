// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// 100% = 1e5
uint128 constant BASE = 1e5;
// 0.3%
uint128 constant SWAP_FEE = 0.003 * 1e5;
// 0.1%
uint128 constant FLASH_FEE = 0.001 * 1e5;
// Virtual shares offset (1 unit of liquidity = 10**off shares)
uint128 constant OFF = 3;
