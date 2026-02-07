// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

uint256 constant Q96 = 1 << 96;

library Math {
    function max(int24 x, int24 y) internal pure returns (int24 z) {
        z = x >= y ? x : y;
    }

    function min(int24 x, int24 y) internal pure returns (int24 z) {
        z = x <= y ? x : y;
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
