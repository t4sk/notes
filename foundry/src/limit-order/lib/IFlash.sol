// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IFlash {
    function flash(uint128 a0, uint128 a1, uint128 f0, uint128 f1) external;
}

