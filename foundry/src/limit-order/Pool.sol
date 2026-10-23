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

library Bitmap {}

uint256 constant B = 1.0001 * 1e27;

// TODO: multi token
// TODO: limit order hook
contract Pool {
    using SafeTransfer for IERC20;
    using Bitmap for mapping(int24 => uint256);

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
    mapping(int24 => uint256) public bitmap;
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

            rem -= cin;
            out += cout;

            // TODO: get next tick
            t = 0;
        }
    }
}
