// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Bit} from "./Bit.sol";

// TODO: compressed
library Bitmap {
    // int24
    //     16    8
    // x = x0 | x1
    function set(mapping(int16 => uint256) storage map, int24 t) internal {
        int16 x0 = int16(t >> 8);
        uint8 x1 = uint8(uint24(t));
        map[x0] |= uint256(1) << x1;
    }

    function del(mapping(int16 => uint256) storage map, int24 t) internal {
        int16 x0 = int16(t >> 8);
        uint8 x1 = uint8(uint24(t));
        map[x0] &= ~(uint256(1) << x1);
    }

    function next(mapping(int16 => uint256) storage map, int24 t, bool gt)
        internal
        view
        returns (int24 n, bool init)
    {
        int16 x0 = int16(t >> 8);
        uint8 x1 = uint8(uint24(t));

        // TODO: does search direction depend on sign of t?
        if (gt) {
            // 1s to the left of x1
            uint256 mask = ~((uint256(1) << x1) - 1) - (uint256(1) << x1);
            uint256 bits = map[x0] & mask;

            init = bits != 0;

            // TODO: check cast
            n = init
                ? int24(x0 << 8) | int24(uint24(Bit.lsb(bits)))
                : int24((x0 + 1) << 8);
        } else {
            // 1s to the right of x1
            uint256 mask = (uint256(1) << x1) - 1;
            uint256 bits = map[x0] & mask;

            init = bits != 0;

            // TODO: check cast
            n = init
                ? int24(x0 << 8) | int24(uint24(Bit.msb(bits)))
                : int24((x0 - 1) << 8);
        }
    }
}
