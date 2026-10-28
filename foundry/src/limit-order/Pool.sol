// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";
import {Liq} from "./lib/Liq.sol";
import {Bitmap} from "./lib/Bitmap.sol";

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

uint256 constant B = 1.0001 * 1e27;

// TODO: multi token
// TODO: limit order hook
// TODO: Lean / tama?

// Liquidity
// L = Px + y
// Liquidity shares
// (T + s) / T = (a + L) / L -> s / T = a / L
// withdraw = P * bucket.x * s / T + bucket.y * s / T = (P*bucket.x + bucket.y) * s / T = L * s / T
contract Pool {
    using SafeTransfer for IERC20;
    using Bitmap for mapping(int16 => uint256);

    struct Bucket {
        // Normalized coin X amount [1e18]
        uint128 x;
        // Normalized coin Y amount [1e18]
        uint128 y;
        // TODO: remove liq, store price, calc total liq when needed?
        // TODO: use uint128?
        // Liquidity = p(i) * X[i] + Y[i] [1e27]
        uint256 l;
        // TODO: split total shares into mapping? - avoids sload on swap
        // Total shares
        uint128 t;
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
    uint128 constant FEE = 0.003 * 1e5;
    // Virtual shares offset (1 unit of liquidity = 10**off shares)
    uint128 constant OFF = 3;

    // Liquidity
    //      Y | X
    // - <- tick -> +

    int24 public tick;
    // int24 = int16 | int8
    mapping(int16 => uint256) public bitmap;
    mapping(int24 => Bucket) public buckets;
    // Tick => user => liquidity shares
    mapping(int24 => mapping(address => uint256)) public shares;

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

        Bucket storage buck = buckets[t];
        // TODO: check type (uint128 big enough)?
        // TODO: fix cast
        uint128 s =
            Liq.shares(uint128(l), uint128(buck.l), uint128(buck.t), OFF);
        require(s >= min, "s < min");

        buck.x += x;
        buck.y += y;
        buck.l += l;
        buck.t += s;

        shares[t][msg.sender] += s;

        bitmap.set(t);

        if (c0 > 0) {
            coin0.safeTransferFrom(msg.sender, address(this), uint256(c0));
        }
        if (c1 > 0) {
            coin1.safeTransferFrom(msg.sender, address(this), uint256(c1));
        }

        return (c0, c1, l);
    }

    function dec(int24 t, uint128 s, uint128 min0, uint128 min1)
        external
        returns (uint128 c0, uint128 c1)
    {
        // TODO: vault math
        shares[t][msg.sender] -= s;

        Bucket storage buck = buckets[t];
        // TODO: fix cast
        uint128 l = Liq.amt(s, buck.t, uint128(buck.l), OFF);

        // TODO: use muldiv?
        uint128 x = u128(uint256(buck.x) * l / buck.l);
        uint128 y = u128(uint256(buck.y) * l / buck.l);

        buck.x -= x;
        buck.y -= y;
        buck.l -= l;
        buck.t -= s;

        // TODO: when t = 0?
        if (buck.l == 0) {
            bitmap.del(t);
            // TODO: clear out x, y, xfee and yfee?
        }

        c0 = x / norm0;
        c1 = y / norm1;

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
            // TODO: skip not init or liq = 0
            Bucket storage buck = buckets[t];
            // TODO: store in storage?
            uint128 p = t >= 0
                ? u128(pow(B, uint256(uint24(t))))
                : u128(RAY_256 / pow(B, uint256(uint24(-t))));
            // px = y
            uint128 cin;
            uint128 cout;
            // Fee on amount in
            uint128 fin;
            if (zero) {
                // x -> y
                // px = y -> max x = y / p
                // TODO: check buck.y * RAY / p <= u128
                // TODO: p > 0?
                uint128 max_cin = min(muldiv(buck.y, RAY_128, p), buck.x);
                uint128 max_fin = max_cin * FEE / 1e5;

                if (rem >= max_cin + max_fin) {
                    fin = max_fin;
                    cin = max_cin;
                } else {
                    fin = rem * FEE / 1e5;
                    cin = rem - fin;
                }

                // TODO: check round trip rounding errors
                // TODO: check p*cin/RAY_128 <= u128
                cout = min(muldiv(p, cin, RAY_128), buck.y);

                buck.x += cin + fin;
                buck.y -= cout;
            } else {
                // y -> x
                // px = y -> max y = px
                uint128 max_cin = min(muldiv(buck.x, p, RAY_128), buck.y);
                uint128 max_fin = max_cin * FEE / 1e5;

                if (rem >= max_cin + max_fin) {
                    fin = max_fin;
                    cin = max_cin;
                } else {
                    fin = rem * FEE / 1e5;
                    cin = rem - fin;
                }

                // TODO: check p*cin/RAY_128 <= u128
                // TODO: check p > 0?
                cout = min(muldiv(cin, RAY_128, p), buck.x);

                buck.x -= cout;
                buck.y += cin + fin;
            }

            fee += fin;
            // TODO: check underflow
            rem -= cin + fin;
            out += cout;

            // TODO: skip to next tick if not init
            (t,) = bitmap.next(t, !zero);
        }

        tick = t;
    }
}
