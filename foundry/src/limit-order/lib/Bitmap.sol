// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Bit} from "./Bit.sol";

library Bitmap {
    // Tick spacing
    // 1 ~ 0.01%
    // 10 ~ 0.1%
    // 100 ~ 1.005%
    // delta price % = (1.0001^S - 1)

    // int24
    //     16    8
    // x = x0 | x1
    function split(int24 t, int24 s)
        internal
        pure
        returns (int16 x0, uint8 x1)
    {
        require(t % s == 0, "tick spacing");
        // Compressed tick
        int24 c = t / s;
        x0 = int16(c >> 8);
        x1 = uint8(uint24(c));
    }

    function set(mapping(int16 => uint256) storage map, int24 t, int24 s)
        internal
    {
        (int16 x0, uint8 x1) = split(t, s);
        map[x0] |= uint256(1) << x1;
    }

    function del(mapping(int16 => uint256) storage map, int24 t, int24 s)
        internal
    {
        (int16 x0, uint8 x1) = split(t, s);
        map[x0] &= ~(uint256(1) << x1);
    }

    // TODO: need to bound t so that x0 + 1 and x0 - 1 doesn't overflow
    function next(
        mapping(int16 => uint256) storage map,
        // Tick
        int24 t,
        // Tick spacing
        int24 s,
        bool gt
    ) internal view returns (int24 n, bool init) {
        (int16 x0, uint8 x1) = split(t, s);

        // TODO: does search direction depend on sign of t?
        if (gt) {
            if (x1 == 255) {
                return (s * (int24(x0 + 1) << 8), map[x0 + 1] != 0);
            }

            // x1 < 255
            // 1s to the left of x1
            uint256 mask = type(uint256).max << (x1 + 1);
            uint256 bits = map[x0] & mask;

            init = bits != 0;

            // TODO: check cast
            n = init
                ? s * (int24(x0 << 8) | int24(uint24(Bit.lsb(bits))))
                : s * (int24((x0 + 1) << 8));
        } else {
            if (x1 == 0) {
                return (s * (int24(x0 - 1) << 8), map[x0 - 1] != 0);
            }

            // x1 > 0
            // 1s to the right of x1
            uint256 mask = (uint256(1) << x1) - 1;
            uint256 bits = map[x0] & mask;

            init = bits != 0;

            // TODO: check cast
            n = init
                ? s * (int24(x0 << 8) | int24(uint24(Bit.msb(bits))))
                : s * (int24((x0 - 1) << 8));
        }
    }
}
