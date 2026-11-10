// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";
import {
    RAY_128,
    RAY_256,
    min,
    max,
    mul,
    muldiv,
    u128,
    pow
} from "./lib/Math.sol";
import {Liq} from "./lib/Liq.sol";
import {Swap} from "./lib/Swap.sol";
import {Price} from "./lib/Price.sol";
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

// TODO: multi token
// TODO: limit order hook
// TODO: Lean / tama?

// Liquidity
// L = Px + y
// Liquidity shares
// (T + s) / T = (a + L) / L -> s / T = a / L
// withdraw = P * bin.x * s / T + bin.y * s / T = (P*bin.x + bin.y) * s / T = L * s / T
contract Pool {
    using SafeTransfer for IERC20;
    using Bitmap for mapping(int16 => uint256);

    // Liquidity
    struct Bin {
        // Normalized coin X amount [1e18]
        uint128 x;
        // Normalized coin Y amount [1e18]
        uint128 y;
        // TODO: remove liq, store price, calc total liq when needed?
        // Price of X in terms of Y [1e27]
        uint128 p;
        // TODO: split total shares into mapping? - avoids sload on swap
        // Total shares
        uint128 s;
    }

    // Swap
    // - limit orders are execute first before market swaps
    // - limit order fees goes to liquidity providers
    // Bundle of limit orders in the same price
    // TODO: pack storage for cheaper gas
    struct Bundle {
        // TODO: store price?
        uint128 p;
        // [1e18]
        uint128 x;
        // [1e18]
        uint128 y;
        bool zero;
    }

    // 0.3%
    uint128 constant FEE = 0.003 * 1e5;
    // Virtual shares offset (1 unit of liquidity = 10**off shares)
    uint128 constant OFF = 3;
    int24 constant TICK_SPACING = 1;

    bool private transient locked;

    // X
    IERC20 public immutable coin0;
    // Y
    IERC20 public immutable coin1;

    // 10^(18 - token X decimals)
    uint128 public immutable norm0;
    // 10^(18 - token X decimals)
    uint128 public immutable norm1;

    // Liquidity
    //      Y | X
    // - <- tick -> +

    int24 public tick;
    // int24 = int16 | int8
    mapping(int16 => uint256) public bitmap;
    mapping(int24 => Bin) public bins;
    // Tick => user => liquidity shares
    mapping(int24 => mapping(address => uint256)) public shares;

    // tick => slot
    mapping(int24 => uint256) public slots;
    // tick => slot => Bundle
    mapping(int24 => mapping(uint256 => Bundle)) public book;
    // tick => slot => user => amount in
    mapping(int24 => mapping(uint256 => mapping(address => uint128))) public
        ins;

    modifier lock() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }

    constructor(address c0, address c1, int24 t) {
        // TODO: require coin0 < coin1?
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

    function inc(int24 t, uint128 c0, uint128 c1, uint256 min)
        external
        lock
        returns (uint128, uint128, uint256)
    {
        // TODO: check tick bounds
        require(t % TICK_SPACING == 0, "invalid tick");
        require(min > 0, "min = 0");

        // TODO: gas save
        if (t < tick) {
            c0 = 0;
        }
        if (t < tick) {
            c1 = 0;
        }

        Bin storage bin = bins[t];

        uint128 x = c0 * norm0;
        uint128 y = c1 * norm1;
        uint128 p = Price.calc(t);
        uint128 dl = Liq.calc(p, x, y);
        uint128 l = Liq.calc(p, bin.x, bin.y);

        if (bin.p == 0) {
            bin.p = p;
        } else {
            assert(p == bin.p);
        }

        // TODO: check type (uint128 big enough)?
        // TODO: fix cast
        uint128 s = Liq.shares(uint128(dl), uint128(l), uint128(bin.s), OFF);
        require(s >= min, "s < min");

        bin.x += x;
        bin.y += y;
        bin.s += s;

        shares[t][msg.sender] += s;

        bitmap.set(t, TICK_SPACING);

        if (c0 > 0) {
            coin0.safeTransferFrom(msg.sender, address(this), uint256(c0));
        }
        if (c1 > 0) {
            coin1.safeTransferFrom(msg.sender, address(this), uint256(c1));
        }

        return (c0, c1, dl);
    }

    function dec(int24 t, uint128 s, uint128 min0, uint128 min1)
        external
        lock
        returns (uint128 c0, uint128 c1)
    {
        // TODO: check tick bounds
        require(t % TICK_SPACING == 0, "invalid tick");

        // TODO: vault math
        shares[t][msg.sender] -= s;

        Bin storage bin = bins[t];
        // TODO: fix cast
        uint128 l = Liq.calc(bin.p, bin.x, bin.y);
        uint128 dl = Liq.val(s, bin.s, l, OFF);

        // TODO: use muldiv?
        uint128 x = u128(uint256(bin.x) * dl / l);
        uint128 y = u128(uint256(bin.y) * dl / l);

        bin.x -= x;
        bin.y -= y;
        bin.s -= s;

        // TODO: when l = 0 and / or s = 0?
        if (bin.s == 0) {
            Bundle memory bun = book[t][slots[t]];
            if (bun.x == 0 && bun.y == 0) {
                // TODO: del tick if no bundle
                bitmap.del(t, TICK_SPACING);
            }
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

    function put(int24 t, uint128 amt, bool zero)
        external
        lock
        returns (uint256 s)
    {
        // TODO: check tick bounds
        require(t % TICK_SPACING == 0, "invalid tick");
        if (zero) {
            require(tick < t, "tick >= current");
        } else {
            require(t < tick, "tick <= current");
        }

        require(amt > 0, "amt = 0");

        uint128 p = Price.calc(t);

        s = slots[t];
        Bundle storage bun = book[t][s];
        // TODO: check p is not init?
        bun.p = p;
        // TODO: check eq if already init?
        bun.zero = zero;
        if (zero) {
            bun.x += amt * norm0;
        } else {
            bun.y += amt * norm1;
        }
        ins[t][s][msg.sender] += amt;

        bitmap.set(t, TICK_SPACING);

        if (zero) {
            coin0.safeTransferFrom(msg.sender, address(this), uint256(amt));
        } else {
            coin1.safeTransferFrom(msg.sender, address(this), uint256(amt));
        }
    }

    // TODO: split (take and decrease size?)
    function take(
        int24 t,
        uint256 s,
        uint128 delta,
        uint128 x_min,
        uint128 y_min
    ) external lock returns (uint128 x, uint128 y) {
        // TODO: check tick bounds
        require(t % TICK_SPACING == 0, "invalid tick");

        require(s <= slots[t], "invalid slot");

        ins[t][s][msg.sender] -= delta;

        // TODO: use memory?
        Bundle storage bun = book[t][s];

        // TODO: is this correct?
        x = bun.x / delta / norm0;
        y = bun.y / delta / norm1;
        require(x >= x_min, "x < min");
        require(y >= y_min, "y < min");

        bun.x -= x;
        bun.y -= y;

        // TODO: delete bun if 0 coins?
        // TODO: delete from tick bitmap?

        if (bun.zero) {
            if (bun.x == 0) {
                delete book[t][s];
                Bin storage bin = bins[t];
                uint128 l = Liq.calc(bun.p, bin.x, bin.y);
                if (l == 0) {
                    bitmap.del(t, TICK_SPACING);
                }
            }
        } else {
            if (bun.y == 0) {
                delete book[t][s];
                Bin storage bin = bins[t];
                uint128 l = Liq.calc(bun.p, bin.x, bin.y);
                if (l == 0) {
                    bitmap.del(t, TICK_SPACING);
                }
            }
        }

        if (x > 0) {
            coin0.safeTransferFrom(msg.sender, address(this), uint256(x));
        }
        if (y > 0) {
            coin1.safeTransferFrom(msg.sender, address(this), uint256(y));
        }
    }

    function swap(uint128 max_in, uint128 min_out, int24 tick_limit, bool zero)
        external
        lock
        returns (uint128 rem, uint128 out, uint128 fee)
    {
        int24 t = tick;
        rem = max_in * (zero ? norm0 : norm1);

        while (rem > 0 && zero ? t >= tick_limit : t <= tick_limit) {
            // TODO: Skip if tick not init?
            // px = y
            uint128 cin;
            uint128 cout;
            // Fee on amount in
            uint128 fin;

            // TODO: use memory?
            Bin storage bin = bins[t];
            Bundle storage bun = book[t][slots[t]];
            // TODO: assert bun.p = bin.p

            // TODO: fix
            uint128 p;
            uint128 l = Liq.calc(p, bin.x, bin.y);

            if (zero ? bun.y > 0 : bun.x > 0) {
                if (zero) {
                    // y <- x
                    (cin, cout, fin) =
                        Swap.xy(bun.x, bun.y, bun.p, l > 0 ? FEE : 0, rem);
                    // Exclude fin
                    bun.x += cin;
                    bun.y -= cout;
                    if (!bun.zero && bun.y == 0) {
                        slots[t] += 1;
                    }
                } else {
                    // y -> x
                    (cin, cout, fin) =
                        Swap.yx(bun.x, bun.y, bun.p, l > 0 ? FEE : 0, rem);
                    bun.x -= cout;
                    // Exclude fin
                    bun.y += cin;
                    if (bun.zero && bun.x == 0) {
                        slots[t] += 1;
                    }
                }
            }

            // Limit order fee goes to LP
            // TODO: does this cause errors in LP shares?
            if (fin > 0) {
                // TODO: assert bin.l > 0
                if (zero) {
                    bin.x += fin;
                } else {
                    bin.y += fin;
                }
            }

            if (l > 0) {
                if (zero) {
                    (uint128 i, uint128 o, uint128 f) =
                        Swap.xy(bin.x, bin.y, bin.p, FEE, rem);
                    cin += i;
                    cout += o;
                    fin += f;
                    // TODO: need to inc liq?
                    bin.x += cin + fin;
                    bin.y -= cout;
                } else {
                    (uint128 i, uint128 o, uint128 f) =
                        Swap.yx(bin.x, bin.y, bin.p, FEE, rem);
                    cin += i;
                    cout += o;
                    fin += f;
                    bin.x -= cout;
                    // TODO: need to inc liq?
                    bin.y += cin + fin;
                }

                fee += fin;
                // TODO: check underflow
                rem -= cin + fin;
                out += cout;
            }

            (t,) = bitmap.next(t, TICK_SPACING, !zero);
        }

        tick = t;

        out /= zero ? norm1 : norm0;
        require(out >= min_out, "out < min");

        if (zero) {
            // Round in favor of the pool
            coin0.safeTransferFrom(
                msg.sender, address(this), max_in - rem / norm0
            );
            if (out > 0) {
                coin1.safeTransfer(msg.sender, uint256(out));
            }
        } else {
            // Round in favor of the pool
            coin1.safeTransferFrom(
                msg.sender, address(this), max_in - rem / norm1
            );
            if (out > 0) {
                coin0.safeTransfer(msg.sender, uint256(out));
            }
        }
    }
}
