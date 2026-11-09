// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Bit} from "./Bit.sol";

// TODO: test
// TODO: require s > 0
// TODO: need to bound t so that hi + 1 (int16) and hi - 1 (int16) doesn't overflow

library Bitmap {
    // Tick spacing
    // 1 ~ 0.01%
    // 10 ~ 0.1%
    // 100 ~ 1.005%
    // delta price % = (1.0001^S - 1)

    // int24
    //     16    8
    // x = hi | lo
    function split(int24 t, int24 s)
        internal
        pure
        returns (int16 hi, uint8 lo)
    {
        require(t % s == 0, "tick spacing");
        // Compressed tick
        int24 c = t / s;
        // c = (hi << 8) + lo
        // t = c*s
        hi = int16(c >> 8);
        lo = uint8(uint24(c));
    }

    function set(mapping(int16 => uint256) storage map, int24 t, int24 s)
        internal
    {
        (int16 hi, uint8 lo) = split(t, s);
        map[hi] |= uint256(1) << lo;
    }

    function del(mapping(int16 => uint256) storage map, int24 t, int24 s)
        internal
    {
        (int16 hi, uint8 lo) = split(t, s);
        map[hi] &= ~(uint256(1) << lo);
    }

    function next(
        mapping(int16 => uint256) storage map,
        // Tick
        int24 t,
        // Tick spacing
        int24 s,
        // Greater or less than
        bool gt
    )
        internal
        view
        returns (
            // next tick
            int24 n,
            // TODO: remove?
            // True if there are more ticks at map[hi] to the left or right of lo
            bool more
        )
    {
        (int16 hi, uint8 lo) = split(t, s);

        if (gt) {
            if (lo == 255) {
                return (s * (int24(hi + 1) << 8), false);
            }

            // lo < 255
            // 1s to the left of lo
            uint256 mask = type(uint256).max << (lo + 1);
            uint256 bits = map[hi] & mask;

            more = bits != 0;

            // TODO: check cast
            n = more
                ? s * ((int24(hi) << 8) | int24(uint24(Bit.lsb(bits))))
                : s * (int24(hi + 1) << 8);
        } else {
            if (lo == 0) {
                return (s * (int24(hi - 1) << 8), false);
            }

            // lo > 0
            // 1s to the right of lo
            uint256 mask = (uint256(1) << lo) - 1;
            uint256 bits = map[hi] & mask;

            more = bits != 0;

            // TODO: check cast
            n = more
                ? s * ((int24(hi) << 8) | int24(uint24(Bit.msb(bits))))
                : s * (int24(hi - 1) << 8);
        }
    }
}
