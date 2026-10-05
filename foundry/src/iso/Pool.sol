// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";
import {
    WAD_128,
    RAY_128,
    WAD_256,
    RAY_256,
    RAD_256,
    min,
    max,
    u64,
    u128,
    mul,
    muldiv,
    pow
} from "./lib/Math.sol";

// TODO: separate pool code (pool = invariants, helper = calc)

interface IOracle {
    // Returns price of gem in terms of coin (1e27 -> 1e27 gem = 1e27 coin)
    // TODO: 1e27 enough decimals?
    function poke(address gem, address coin)
        external
        returns (bool ok, uint128 price);
}

interface IRateController {
    // [1e18], [1e18], [1e27], [timestamp] -> [1e27]
    function calc(uint128 net, uint128 debt, uint64 dt)
        external
        returns (uint128 rate);
}

// 1e18 = 100%
uint128 constant FEE = 0.05e18;
// 1e18 = 100%
uint128 constant FLASH_FEE = 0.001e18;
// Value to loan V <= (pos.gem / (pos.debt * rac)) [1e27]
uint128 constant V = 1.5e27;
// Liquidation threshold [1e27]
// 1 < 1 + liquidation bonus < K < V
uint128 constant K = 1.1e27;
// DUST (pos.debt * rac) >= DUST
uint256 constant DUST = 100 * 1e27 * 1e18;

// TODO: stop and withdraw?
// TODO: liq amm = oracle?
// TODO: ERC20
// TODO: fee on transfer and rebase?
// TODO: join adapters to normalize to 18 decimals?
// TODO: protcol + treasury fee split
// TODO: sync balance -> protocol yield

// pre = calculation to be done before state updates
// post = calculation to be done after state updates
// Use {0, 1} to indicate {pre, post}

// Borrow rates
// r[i] = borrow rate for time t, i <= t < i + 1

// User borrows x at t = K, debt at t = K + N (pre)
// = x * (1 + r[K]) * (1 + r[K + 1]) * ... * (1 + r[K + N - 1])

// Borrow rate accumulator
// R[0] = 1
// For N > 0
// R[N] = (1 + r[0]) * (1 + r[1]) * ... * (1 + r[N])

// User's debt = x * R[K + N - 1] / R[K - 1] (pre)

// Normalized debt
// User borrows x[0] at time K, borrows or repays x[1] at time K + N, debt at time K + M (0 <= N <= M)
// = (x[0] * R[K + N - 1] / R[K - 1] + x[1]) * R[K + M - 1] / R[K + N - 1]
// = (x[0] / R[K - 1] + x[1] / R[K + N - 1]) * R[K + M - 1]
//   |____________________________________|
//              normalized debt

// d'[u, i] = normalized debt of user u at time i
// D'[i] = total normalized debt at time i
// D[i] = total debt at time i
//      = D'{0}[i] * R[i - 1]
//        (pre)       (pre)

// Yield (gain and loss)
// y[i] = yield gain or loss from time i - 1 (post) to i (pre)
//      = D{0}[i] - D{1}[i - 1]
//        (pre)     (post)
//      = D'{0} * r[i - 1]

// TODO: unbacked loss?

// Pool value
// P[i] = total amount owed to lenders (deposits + interest) at time i (pre)

// Pool value may change between post i - 1 and pre i (although not reflected in state variables)
// P{0}[i] != P{1}[i - 1] is possible

// Pool growth and lender shares
// g[i] = pool growth (lender deposits + interest - loss) from time i - 1 (post) to i (pre)
//      = (P{0}[i] - P{1}[i - 1]) / P{1}[i - 1] (assuming P{i}[i - 1] > 0)
// g[0] = 1

// Lender deposits x at t = K, claims at t = K + N
// x * g[K + 1] * g[K + 2] * ... * g[K + N]

// Pool growth accumulator
// G[0] = 1
// G[N] = g[0] * g[1] * g[2] * ... * g[N] (pre)

// Lender claimable amount
// = x * G[K + N] / G[K]
// Lender shares = x / G[K]

// Lender shares
// s[u, i] = lender u's shares at time i
// T[i] = total shares at time i

// Total shares does not change between post i and pre i + 1
// T{1}[i] = T{0}[i + 1]

// Total owed to lenders
// P{0}[i] = T{0}[i] * G[i]

// Yield split
// F = protocol fee
// y[i] * F = protocol yield
// y[i] * (1 - F) = lender yield

// Utilizatoin rate
// C[i] = total coin supplied at time i
// U[i] = utilization rate at time i
//      = total debt with interest / (total coin supplied - loss)
//      = D'{1}[i] / C{1}[i] (if C{1}[i] > 0)
// utilization rate -> borrow rate -> lender yield

// TODO: check all math doesn't overflow ([ray] * [wad] > u128)
// TODO: check rate >= 1 and rac > 0

// TODO: ERC20
// TODO: exit queue?
// TODO: round down shares and round up debt?
// TODO: transient lock
// TODO: handle debt rate blow up
// TODO: check rounding (down = mint, token out, up for burn, token in)
contract Pool {
    using SafeTransfer for IERC20;

    struct Cdp {
        // [1e18]
        uint128 col;
        // Normalized debt [1e18]
        uint128 debt;
    }

    // Collateral
    IERC20 public immutable gem;
    // Token to borrow
    IERC20 public immutable coin;
    IOracle public immutable oracle;
    IRateController public immutable ctrl;
    // Treasury
    address public immutable pot;

    // Normalize gem decimals to 1e18
    uint128 private immutable gnorm;
    // Normalize coin decimals to 1e18
    uint128 private immutable cnorm;

    // Current borrow rate r[i] [1e27]
    uint128 public rate;
    // Last timestamp rates were updated
    uint64 public last;
    // Rate accumulator R[N] [1e27]
    uint128 public rac;
    // Pool growth accumulator G[N] [1e27]
    uint128 public pac;
    // Total normalized debt [1e18]
    // Total debt with interest = debt * rac
    uint128 public debt;
    // Borrower => CDP
    mapping(address => Cdp) public cdps;

    // Total lender shares [1e18]
    // Total coin's owed (deposit + interest - loss) = pac * pie
    uint128 public pie;
    // Lender shares [1e18]
    mapping(address => uint128) public slices;
    // TODO: Check net * RAY <= pie * pac
    // Current supply (deposit - withdraw - borrow + repay - loss) [1e18]
    uint128 public net;
    // Unbacked loss [1e18]
    uint128 public loss;

    // Liquidation buckets
    struct Bucket {
        // Collateral amount [1e18]
        uint128 col;
        // Normalized debt [1e18]
        uint128 debt;
    }
    // TODO: price band for slot
    // TODO: unit of slot?
    // Slot = pos.col / pos.debt
    mapping(uint128 slot => Bucket) public buckets;

    constructor(address g, address c, address o, address r) {
        // TODO: allow g = c?
        gem = IERC20(g);
        coin = IERC20(c);
        oracle = IOracle(o);
        ctrl = IRateController(r);
        pot = msg.sender;
        rate = RAY_128;
        rac = RAY_128;
        pac = RAY_128;
        last = u64(block.timestamp);

        uint8 gdec = gem.decimals();
        require(gdec <= 18, "gem decimals > 18");
        uint8 cdec = coin.decimals();
        require(cdec <= 18, "coin decimals > 18");
        gnorm = u128(10 ** (18 - gdec));
        cnorm = u128(10 ** (18 - cdec));
    }

    function sync() public {
        uint64 t = u64(block.timestamp);
        uint64 dt = t - last;

        // TODO: check calling sync twice in the same time stamp doesn't change state variables
        if (dt > 0) {
            uint128 d = debt;
            uint128 r0 = rac;

            uint256 d0 = mul(d, r0);
            // TODO: check r >= 1
            uint128 r = pow(rate - RAY_128, uint128(dt));
            uint128 r1 = muldiv(r0, r, RAY_128);
            /* TODO: enforce non decrease?
            r1 = Math.max(r1, r0);
            */
            uint256 d1 = mul(d, r1);
            // y = (d1 - d0) * (1 - F) (TODO: check d1 >= d0)
            //   = d * (r1 - r0) * (1 - F)
            //   = d * (r0 * r - r0) * (1 - F)
            //   = d * r0 * (r - 1) * (1 - F)
            // g = y / d0
            //   = (r - 1) * (1 - F)
            uint128 g = r - RAY_128;
            uint128 fee = muldiv(g, FEE, WAD_128);
            uint128 rem = g - fee;

            // TODO: what to do with fee?
            if (fee > 0) {
                // mint fee * d to treasury?
            }

            // TODO: check g > 0 and pac > 0
            // TODO: check rem > 0
            pac = muldiv(pac, rem, RAY_128);
            rac = r1;
            last = t;
        }
    }

    function post() private {
        // TODO: check rate >= 1
        // uint128 r = ctrl.calc(net, Math.muldiv(debt, rac, RAY_128));
        // rate = r;
    }

    function mint(uint128 amt, uint128 min) external returns (uint128 slice) {
        sync();

        uint128 wad = amt * cnorm;
        slice = muldiv(wad, RAY_128, pac);
        require(slice >= min, "slice < min");

        pie += slice;
        slices[msg.sender] += slice;
        net += wad;

        coin.safeTransferFrom(msg.sender, address(this), amt);
        post();
    }

    function burn(uint128 slice, uint128 min) external returns (uint128 amt) {
        sync();

        uint128 wad = muldiv(slice, pac, RAY_128);
        amt = wad / cnorm;
        require(amt >= min, "amt < min");

        pie -= slice;
        slices[msg.sender] -= slice;
        net -= wad;

        coin.safeTransfer(msg.sender, amt);
        post();
    }

    function poke() public returns (uint128) {
        (bool ok, uint128 price) = oracle.poke(address(gem), address(coin));
        require(ok, "oracle not ok");
        return price;
    }

    function lock(uint128 amt) external {
        gem.safeTransferFrom(msg.sender, address(this), amt);
        cdps[msg.sender].col += amt * gnorm;
    }

    function unlock(uint128 amt) external {
        sync();

        Cdp memory cdp = cdps[msg.sender];
        cdp.col -= amt * gnorm;

        uint128 p = poke();
        require(mul(cdp.debt, rac) < mul(cdp.col, p), "unsafe cdp");

        cdps[msg.sender].col = cdp.col;
        gem.safeTransfer(msg.sender, amt);
    }

    function borrow(uint128 amt) external {
        sync();

        // TODO: require amt >= min

        Cdp memory cdp = cdps[msg.sender];
        // TODO: check amt / rac > 0
        // Round up?
        uint128 wad = amt * cnorm;
        uint128 d = muldiv(wad, RAY_128, rac) + 1;
        cdp.debt += d;

        // TODO: price safety margin?
        uint128 p = poke();
        require(mul(cdp.debt, rac) < mul(cdp.col, p), "unsafe cdp");

        debt += d;
        cdps[msg.sender].debt = cdp.debt;
        net -= wad;
        coin.safeTransfer(msg.sender, amt);

        post();
    }

    function repay(uint128 amt) external {
        sync();

        Cdp memory cdp = cdps[msg.sender];
        uint128 d;
        uint128 max = muldiv(cdp.debt, rac, RAY_128) + 1;
        if (amt * cnorm >= max) {
            d = cdp.debt;
            amt = max / cnorm;
        } else {
            d = min(muldiv(amt * cnorm, RAY_128, rac) + 1, cdp.debt);
        }
        uint128 wad = amt * cnorm;
        cdp.debt -= d;
        // TODO: require min debt

        debt -= d;
        cdps[msg.sender].debt = cdp.debt;
        net += wad;
        coin.safeTransferFrom(msg.sender, address(this), amt);

        post();
    }

    // TODO: dynamic close factor
    // TODO: multiple call for valid slot should not fail
    function liquidate(
        uint128 maxCoinIn,
        uint128 minGemOut,
        uint128 slot,
        uint128 maxSlot
    ) external returns (uint128 coinAmtIn, uint128 gemAmtOut) {
        sync();

        uint128 spot = poke();
        // TODO: FIX rem goes above max when dust must be repaid
        uint128 rem = maxCoinIn * cnorm / rac;
        // debt
        uint128 d;
        // col
        uint128 c;
        // loss
        uint128 l;

        while (rem > 0 && slot <= maxSlot) {
            // Liquidation condition
            // pos.col * spot / (pos.debt * rac) <= K
            require(mul(slot, spot) <= mul(K, rac), "invalid slot");
            Bucket memory buck = buckets[slot];
            // TODO:: handle buck.debt = 0 and buck.col = 0

            // Maximum debt to repay from this bucket
            uint128 cap = min(buck.debt, rem);
            // Caller cannot leave dust
            if (mul(buck.debt - cap, rac) < DUST) {
                cap = buck.debt;
            }

            // TODO: calculate liquidation bonus
            uint128 bonus = 0.05e18;

            // Calculate repayment amount and col amount
            // col * spot = repay * rac * (1 + bonus)
            uint128 re = cap;
            uint128 col;
            if (spot == 0) {
                col = buck.col;
                re = 0;
            } else {
                // TODO: use Math to handle overflow and precision loss
                //    [wad] * [ray] * [wad] / [ray] / [wad] = [wad]
                col = re * rac * (WAD_128 + bonus) / spot / WAD_128;
            }

            // Cap col and recalculate repayment amount
            if (col > buck.col) {
                col = buck.col;
                // TODO: use Math to handle overflow and precision loss
                //   [wad] * [ray] * [wad] / [ray] / [wad]
                re = col * spot * WAD_128 / rac / (WAD_128 + bonus) + 1;
            }

            // TODO: check re <= b.debt
            // TODO: check col <= b.col
            Bucket storage b = buckets[slot];
            b.debt -= re;
            b.col -= col;

            d += re;
            c += col;
            // TODO: check cap >= re
            l += cap - re;
            // TODO: FIX re >= rem when dust clean up is triggered
            rem -= min(re, rem);

            // TODO: update slot
            // slot = next slot
        }

        if (l > 0) {
            loss += l;
        }

        // TODO: update net?

        // coinAmtIn = d * rac / RAY / cnorm + 1;
        // gemAmtOut = c / gnorm;

        require(coinAmtIn <= maxCoinIn, "coin in > max");
        require(gemAmtOut >= minGemOut, "gem out < min");
        coin.safeTransferFrom(msg.sender, address(this), coinAmtIn);
        gem.safeTransfer(msg.sender, gemAmtOut);
    }

    function flash(uint128 c, uint128 g) external {}

    function donate(uint128 amt) external {
        loss -= amt * cnorm;
        coin.safeTransferFrom(msg.sender, address(this), amt);
    }
    // TODO: auth set params (K, V, LIQ_MIN_BONUS, LIQ_MAX_BONUS)
    // TODO: pause
    // TODO: emergency recovery
    // TODO: sweep dust to treasury
}

// TODO: price band or linked list?
// Doubly linked list <- still need compression for buckets to be useful
// insert   O(N)
// remove   O(1)
// update (remove + insert) O(1) + O(N)
// find top O(1)

// Price band
//             [wad] * [ray] / [wad]
// C * slot <= pos.col * RAY / pos.debt < C * slot + 1
// slot = pos.col * RAY / pos.debt / C

// Compression
// C small -> sparse slots
// C large -> large price range grouped into a single slot
//                        C = 10 | 100
// 1 * 100 / 10 = 10 / C   |  1  |   0
// 2 * 100 / 10 = 20 / C   |  2  |   0
// 3 * 100 / 10 = 30 / C   |  3  |   0
// 11 * 100 / 10 = 110 / C | 11  |   1

//        [1e18] * [1e27] / [1e18] = [1e27] / [C]
// slot = pos.col * RAY / pos.debt / C

// liquidation price
// pos.col * spot <= K * pos.debt * rac

// Uniswap v3 tick
//                2.94e-39  to 3.4e38
// tick = int24 (-8,388,608 to +8,388,607)

// Slot precision
// 1 slot = 1e18
// 0 <= slot <= 1e18
// slot <= 1e18 * [1e18] < 2**128

// Bitmap
// 128 / 2 = 64
// 128 / 4 = 32

// 2**8 = 256
// uint128 -> mapping(mapping(uint256 => uint64))

// Tree
// 256 = 2^8
// 3 level tree = 256^3 = 2^24
// 4 level tree = 256^4 = 2^32

contract Bitmap {
    // [15 to 8] -> [7 to 0]
    mapping(uint256 => uint256) public b0;
    // [23 to 16] -> [15 to 8]
    mapping(uint256 => uint256) public b1;
    // [31 to 24] -> [23 to 16]
    mapping(uint256 => uint256) public b2;
    // [39 to 32] -> [31 to 24]
    mapping(uint256 => uint256) public b3;
    // [47 to 40] -> [39 to 32]
    mapping(uint256 => uint256) public b4;
    // [55 to 48] -> [47 to 40]
    mapping(uint256 => uint256) public b5;
    // [63 to 56] -> [55 to 48]
    mapping(uint256 => uint256) public b6;

    function insert(uint64 x) public {
        // 64 bits
        // x = [ x7 ][ x6 ][ x5 ][ x4 ][ x3 ][ x2 ][ x1 ][ x0 ]
        //       8     8     8     8     8     8     8     8
        uint8 x0 = uint8(x >> 0);
        uint8 x1 = uint8(x >> 8);
        uint8 x2 = uint8(x >> 16);
        uint8 x3 = uint8(x >> 24);
        uint8 x4 = uint8(x >> 32);
        uint8 x5 = uint8(x >> 40);
        uint8 x6 = uint8(x >> 48);
        uint8 x7 = uint8(x >> 56);

        b0[x1] |= uint256(1) << x0;
        b1[x2] |= uint256(1) << x1;
        b2[x3] |= uint256(1) << x2;
        b3[x4] |= uint256(1) << x3;
        b4[x5] |= uint256(1) << x4;
        b5[x6] |= uint256(1) << x5;
        b6[x7] |= uint256(1) << x6;
    }
}
