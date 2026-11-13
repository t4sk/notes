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
import {Bitmap} from "./lib/Bitmap.sol";
import {Tick} from "./lib/Tick.sol";
import {Liq} from "./lib/Liq.sol";
import {Swap} from "./lib/Swap.sol";
import {Price} from "./lib/Price.sol";

// TODO: multi token
// TODO: limit order hook
// TODO: Lean / tama?

// X[i] = token X in tick i
// Y[i] = token Y in tick i
// L[i] = liquidity at tick i
//      = p(i) * X[i] + Y[i]

// t = current tick
// For i < t -> L[i] = Y[i]
// For t < i -> L[i] = p(i) * X[i]

contract Pool {
    using SafeTransfer for IERC20;
    using Bitmap for mapping(int16 => uint256);

    // Liquidity
    struct Bin {
        // Normalized coin X amount [1e18]
        uint128 x;
        // Normalized coin Y amount [1e18]
        uint128 y;
        // Total shares
        uint128 s;
    }

    // Swap
    // - limit orders are execute first before bin liquidity
    // - limit order fees goes to liquidity providers
    // Bundle of limit orders in the same price
    struct Bundle {
        // Normalized coin X amount [1e18]
        uint128 x;
        // Normalized coin Y amount [1e18]
        uint128 y;
        // Swap coin 0 to 1
        bool zero;
    }

    // 0.3%
    uint128 private constant FEE = 0.003 * 1e5;
    // Virtual shares offset (1 unit of liquidity = 10**off shares)
    uint128 private constant OFF = 3;
    // TODO: immutable?
    int24 private constant TICK_SPACING = 1;

    bool private transient locked;

    // Coin X
    IERC20 public immutable coin0;
    // Coin Y
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
    // int24 => price of X in terms of Y [1e27]
    mapping(int24 => uint128) public prices;

    // Bin
    mapping(int24 => Bin) public bins;
    // Tick => user => liquidity shares
    mapping(int24 => mapping(address => uint256)) public shares;

    // Bundle
    // tick => slot
    mapping(int24 => uint256) public slots;
    // tick => slot => Bundle
    mapping(int24 => mapping(uint256 => Bundle)) public buns;
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
        require(coin0 != coin1, "coin 0 = coin 1");
        coin0 = IERC20(c0);
        coin1 = IERC20(c1);

        uint8 dec0 = coin0.decimals();
        require(dec0 <= 18, "coin0 decimals > 18");
        uint8 dec1 = coin1.decimals();
        require(dec1 <= 18, "coin1 decimals > 18");
        norm0 = u128(10 ** (18 - dec0));
        norm1 = u128(10 ** (18 - dec1));

        Tick.check(t, TICK_SPACING);
        tick = t;
    }

    function inc(int24 t, uint128 c0, uint128 c1, uint256 min)
        external
        lock
        returns (uint128, uint128, uint256)
    {
        Tick.check(t, TICK_SPACING);
        require(min > 0, "min = 0");

        uint128 p = Price.calc(t);

        // TODO: move to lib
        uint128 dx;
        uint128 dy;
        (dx, dy, c0, c1) = Liq.calc_dx_dy_in(p, t, tick, c0, c1, norm0, norm1);

        Bin storage bin = bins[t];

        // TODO: require dl > 0?
        uint128 dl = Liq.calc(p, dx, dy);
        uint128 l = Liq.calc(p, bin.x, bin.y);

        if (prices[t] == 0) {
            prices[t] = p;
        }
        // TODO: assert(p == prices[t]);

        // TODO: check type (uint128 big enough)?
        // TODO: fix cast
        uint128 s = Liq.shares(uint128(dl), uint128(l), uint128(bin.s), OFF);
        require(s >= min, "s < min");

        bin.x += dx;
        bin.y += dy;
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
        Tick.check(t, TICK_SPACING);

        // TODO: vault math
        shares[t][msg.sender] -= s;

        uint128 p = prices[t];
        Bin storage bin = bins[t];
        // TODO: fix cast
        uint128 l = Liq.calc(p, bin.x, bin.y);
        uint128 dl = Liq.val(s, bin.s, l, OFF);

        // TODO: use muldiv?
        uint128 dx = u128(uint256(bin.x) * dl / l);
        uint128 dy = u128(uint256(bin.y) * dl / l);

        bin.x -= dx;
        bin.y -= dy;
        bin.s -= s;

        // TODO: when l = 0 and / or s = 0?
        if (bin.s == 0) {
            Bundle memory bun = buns[t][slots[t]];
            if (bun.x == 0 && bun.y == 0) {
                // TODO: del tick if no bundle
                bitmap.del(t, TICK_SPACING);
            }
            // TODO: clear out x, y?
        }

        c0 = dx / norm0;
        c1 = dy / norm1;

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
        Tick.check(t, TICK_SPACING);

        if (zero) {
            require(tick < t, "tick >= current");
        } else {
            require(t < tick, "tick <= current");
        }

        require(amt > 0, "amt = 0");

        uint128 p = Price.calc(t);

        if (prices[t] == 0) {
            prices[t] = p;
        }
        assert(p == prices[t]);

        s = slots[t];
        Bundle storage bun = buns[t][s];
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
    ) external lock returns (uint128 dx, uint128 dy) {
        Tick.check(t, TICK_SPACING);

        require(s <= slots[t], "invalid slot");

        ins[t][s][msg.sender] -= delta;

        // TODO: use memory?
        Bundle storage bun = buns[t][s];

        // TODO: is this correct?
        dx = bun.x / delta / norm0;
        dy = bun.y / delta / norm1;
        require(dx >= x_min, "x < min");
        require(dy >= y_min, "y < min");

        bun.x -= dx;
        bun.y -= dy;

        // TODO: delete bun if 0 coins?
        // TODO: delete from tick bitmap?
        // TODO: check p > 0?
        uint128 p = prices[t];

        if (bun.zero) {
            if (bun.x == 0) {
                delete buns[t][s];
                Bin storage bin = bins[t];
                uint128 l = Liq.calc(p, bin.x, bin.y);
                if (l == 0) {
                    bitmap.del(t, TICK_SPACING);
                }
            }
        } else {
            if (bun.y == 0) {
                delete buns[t][s];
                Bin storage bin = bins[t];
                uint128 l = Liq.calc(p, bin.x, bin.y);
                if (l == 0) {
                    bitmap.del(t, TICK_SPACING);
                }
            }
        }

        if (dx > 0) {
            coin0.safeTransferFrom(msg.sender, address(this), uint256(dx));
        }
        if (dy > 0) {
            coin1.safeTransferFrom(msg.sender, address(this), uint256(dy));
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
            Bundle storage bun = buns[t][slots[t]];
            // TODO: assert bun.p = bin.p

            // TODO: check p > 0?
            uint128 p = prices[t];
            uint128 l = Liq.calc(p, bin.x, bin.y);

            if (zero ? bun.y > 0 : bun.x > 0) {
                if (zero) {
                    // y <- x
                    (cin, cout, fin) =
                        Swap.xy(bun.x, bun.y, p, l > 0 ? FEE : 0, rem);
                    // Exclude fin
                    bun.x += cin;
                    bun.y -= cout;
                    if (!bun.zero && bun.y == 0) {
                        slots[t] += 1;
                    }
                } else {
                    // y -> x
                    (cin, cout, fin) =
                        Swap.yx(bun.x, bun.y, p, l > 0 ? FEE : 0, rem);
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
                        Swap.xy(bin.x, bin.y, p, FEE, rem);
                    cin += i;
                    cout += o;
                    fin += f;
                    // TODO: need to inc liq?
                    bin.x += cin + fin;
                    bin.y -= cout;
                } else {
                    (uint128 i, uint128 o, uint128 f) =
                        Swap.yx(bin.x, bin.y, p, FEE, rem);
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
