// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";

// Swap
// p*dx = dy

// p(i) = 1.0001^i
// X[i] = token X in tick i
// Y[i] = token Y in tick i
// L[i] = liquidity at tick i
//      = p(i) * X[i] + Y[i]

// t = current tick
// For i < t -> L[i] = Y[i]
// For t < i -> L[i] = p(i) * X[i]

uint128 constant RAY_128 = 1e27;
uint256 constant RAY_256 = 1e27;

function min(uint128 x, uint128 y) pure returns (uint128 z) {
    z = x <= y ? x : y;
}

function max(uint128 x, uint128 y) pure returns (uint128 z) {
    z = x >= y ? x : y;
}

function mul(uint128 x, uint128 y) pure returns (uint256 z) {
    z = uint256(x) * uint256(y);
}

function muldiv(uint128 x, uint128 y, uint128 d) pure returns (uint128 z) {
    z = u128(uint256(x) * uint256(y) / uint256(d));
}

function u128(uint256 x) pure returns (uint128 z) {
    require(x <= type(uint128).max, "x > u128 max");
    z = uint128(x);
}

function pow(uint256 b, uint256 x) pure returns (uint256 z) {}

library Bit {
    function msb(uint256 x) internal pure returns (uint8 z) {
        require(x > 0, "x = 0");
        // clz(x) = Number of leading 0s in x, 256 if x = 0
        assembly {
            z := sub(255, clz(x))
        }
    }

    function lsb(uint256 x) internal pure returns (uint8 z) {
        require(x > 0, "x = 0");
        // Why -x = ~x + 1
        // x & ~x = all 1s = 2^256 - 1
        // 2^256 = 0
        // -x = ~x + 1

        // Why lsb = x & (~x + 1) = x & -x
        //  x     = 110100
        // ~x     = 001011 (negate x, least significant bit of x is now 0, all lower bits = 1)
        // ~x + 1 = 001100 (move from least to most significant bit of ~x, flip all 1 to 0, flip first 0 to 1, stop)
        //              LEFT             | LSB      | RIGHT
        // ~x + 1 = opposite of x's bits | 1 at lsb | all 0s
        // x & (~x + 1)
        // LEFT = AND x's bits and its opposite = 0s
        // LSB = both x and (~x + 1) = 1
        // RIGHT = (~x + 1) is all 0s = 0s
        assembly {
            // x & -x
            z := sub(255, clz(and(x, sub(0, x))))
        }
    }
}

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

uint256 constant B = 1.0001 * 1e27;

// TODO: multi token
// TODO: limit order hook
// TODO: Lean / tama?
contract Pool {
    using SafeTransfer for IERC20;
    using Bitmap for mapping(int16 => uint256);

    struct Bucket {
        // Normalized coin X amount [1e18]
        uint128 x;
        // Normalized coin Y amount [1e18]
        uint128 y;
        // TODO: use uint128?
        // Liquidity = p(i) * X[i] + Y[i] [1e27]
        uint256 l;
        // X
        uint128 xfee;
        // Y
        uint128 yfee;
    }

    // X
    IERC20 public immutable coin0;
    // Y
    IERC20 public immutable coin1;

    // 10^(18 - token X decimals)
    uint128 public immutable norm0;
    // 10^(18 - token X decimals)
    uint128 public immutable norm1;

    // 0.3%
    uint128 public constant FEE = 0.003 * 1e5;

    // Liquidity
    //      Y | X
    // - <- tick -> +

    int24 public tick;
    // int24 = int16 | int8
    mapping(int16 => uint256) public bitmap;
    mapping(int24 => Bucket) public buckets;
    // Tick => user => liquidity [1e27]
    mapping(int24 => mapping(address => uint256)) public liqs;

    constructor(address c0, address c1, int24 t) {
        coin0 = IERC20(c0);
        coin1 = IERC20(c1);

        uint8 dec0 = coin0.decimals();
        require(dec0 <= 18, "coin0 decimals > 18");
        uint8 dec1 = coin1.decimals();
        require(dec1 <= 18, "coin1 decimals > 18");
        norm0 = u128(10 ** (18 - dec0));
        norm1 = u128(10 ** (18 - dec1));

        tick = t;
    }

    function inc(int24 i, uint128 c0, uint128 c1, uint256 min)
        external
        returns (uint128, uint128, uint256)
    {
        require(min > 0, "min = 0");

        int24 t = tick;

        if (i < t) {
            c0 = 0;
        }
        if (t < i) {
            c1 = 0;
        }

        uint128 x = c0 * norm0;
        uint128 y = c1 * norm1;
        uint128 p = t >= 0
            ? u128(pow(B, uint256(uint24(t))))
            : u128(RAY_256 / pow(B, uint256(uint24(-t))));
        uint256 l = mul(p, x) + mul(y, RAY_128);
        require(l >= min, "l < min");

        Bucket storage buck = buckets[t];
        buck.x += x;
        buck.y += y;
        // TODO: use vault math or include fees in liq calc?
        buck.l += l;

        liqs[t][msg.sender] += l;

        bitmap.set(t);

        if (c0 > 0) {
            coin0.safeTransferFrom(msg.sender, address(this), uint256(c0));
        }
        if (c1 > 0) {
            coin1.safeTransferFrom(msg.sender, address(this), uint256(c1));
        }

        return (c0, c1, l);
    }

    function dec(int24 t, uint256 l, uint128 min0, uint128 min1)
        external
        returns (uint128 c0, uint128 c1)
    {
        liqs[t][msg.sender] -= l;

        Bucket storage buck = buckets[t];
        // TODO: use muldiv?
        uint128 x = u128(uint256(buck.x) * l / buck.l);
        uint128 y = u128(uint256(buck.y) * l / buck.l);
        uint128 xf = u128(uint256(buck.xfee) * l / buck.l);
        uint128 yf = u128(uint256(buck.yfee) * l / buck.l);

        buck.x -= x;
        buck.y -= y;
        buck.l -= l;
        buck.xfee -= xf;
        buck.yfee -= yf;

        if (buck.l == 0) {
            bitmap.del(t);
            // TODO: clear out x, y, xfee and yfee?
        }

        c0 = (x + xf) / norm0;
        c1 = (y + yf) / norm1;

        require(c0 >= min0, "c0 < min");
        require(c1 >= min1, "c1 < min");

        if (c0 > 0) {
            coin0.safeTransfer(msg.sender, uint256(c0));
        }
        if (c1 > 0) {
            coin1.safeTransfer(msg.sender, uint256(c1));
        }
    }

    function swap(uint128 max_in, uint128 min_out, int24 tick_limit, bool zero)
        external
        returns (uint128 rem, uint128 out, uint128 fee)
    {
        int24 t = tick;
        rem = max_in * (zero ? norm0 : norm1);

        while (rem > 0 && zero ? t >= tick_limit : t <= tick_limit) {
            Bucket storage buck = buckets[t];
            // TODO: store in storage?
            uint128 p = t >= 0
                ? u128(pow(B, uint256(uint24(t))))
                : u128(RAY_256 / pow(B, uint256(uint24(-t))));
            // px = y
            uint128 cin;
            uint128 cout;
            if (zero) {
                // x -> y
                // px = y -> max x = y / p
                // TODO: check buck.y * RAY / p <= u128
                // TODO: p > 0?
                uint128 max_cin = min(muldiv(buck.y, RAY_128, p), buck.x);
                cin = min(rem, max_cin);
                // TODO: check round trip rounding errors
                // TODO: check p*cin/RAY_128 <= u128
                cout = min(muldiv(p, cin, RAY_128), buck.y);

                buck.x += cin;
                buck.y -= cout;
            } else {
                // y -> x
                // px = y -> max y = px
                uint128 max_cin = min(muldiv(buck.x, p, RAY_128), buck.y);
                cin = min(rem, max_cin);
                // TODO: check p*cin/RAY_128 <= u128
                // TODO: check p > 0?
                cout = min(muldiv(cin, RAY_128, p), buck.x);

                buck.x -= cout;
                buck.y += cin;
            }

            // TODO: fee
            uint128 f = cout * FEE / 1e5;
            cout -= f;
            if (zero) {
                buck.yfee += f;
            } else {
                buck.xfee += f;
            }

            fee += f;
            rem -= cin;
            out += cout;

            // TODO: next tick
            t = 0;
        }

        tick = t;
    }
}
