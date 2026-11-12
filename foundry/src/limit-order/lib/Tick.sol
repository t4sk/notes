// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

int24 constant MIN_TICK = type(int24).min;
int24 constant MAX_TICK = type(int24).max;

library Tick {
    function check(int24 t, int24 s) internal pure {
        require(t % s == 0, "t % s != 0");
        require(t <= MAX_TICK, "t > max");
        require(t >= MIN_TICK, "t < min");
    }
}
