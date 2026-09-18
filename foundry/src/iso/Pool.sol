// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";

interface IOracle {
    // return ok = false, if price is stale
    function poke(address gem, address coin)
        external
        returns (bool ok, uint128 price);
}

interface IRateController {}

uint128 constant W = 1e18;

library Math {
    function u64(uint256 x) internal pure returns (uint64 z) {
        require(x <= type(uint64).max, "x > u64 max");
        z = uint64(x);
    }

    // Binomial expansion
    // (1+x)^n = 1+n*x+(n*(n-1)/2)*x^2+[n*(n-1)*(n-2)/6*x^3...
    // TODO: check math
    function pow(uint128 x, uint128 n) internal pure returns (uint128 z) {
        z = W + n * x + n * (n - 1) / 2 * x * x / W + n * (n - 1) * (n - 2) / 6
            * x * x / W * x / W;
    }

    function u128(uint256 x) internal pure returns (uint128 z) {
        require(x <= type(uint128).max, "x > u128 max");
        z = uint128(x);
    }

    function mul(uint128 x, uint128 y) internal pure returns (uint256 z) {
        z = uint256(x) * uint256(y);
    }
}

// TODO: stop and withdraw?
// TODO: liq amm = oracle?
// TODO: ERC20
// TODO: fee on transfer and rebase?
// TODO: join adapters to normalize to 18 decimals?
// TODO: protcol + treasury fee split
// TODO: sync balance -> protocol yield

// Utilization rate = total debt with interest / total coin supplied
// borrow rate <- f(utilization rate)

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

// TODO: Invariants to check
// rate >= 1 and rac > 0

contract Pool {
    using SafeTransfer for IERC20;

    IERC20 public immutable gem;
    IERC20 public immutable coin;

    // Current borrow rate r[i]
    uint128 public rate;
    // Last timestamp rates were updated
    uint64 public last;
    // Rate accumulator R[N]
    uint128 public rac;
    // Pool growth accumulator G[N]
    uint128 public pac;
    // Total normalized debt
    // Total debt with interest = debt * rac
    uint128 public debt;

    constructor(address g, address c) {
        gem = IERC20(g);
        coin = IERC20(c);
        rate = W;
        last = Math.u64(block.timestamp);
    }

    function sync() public {
        uint64 t = Math.u64(block.timestamp);
        uint64 dt = t - last;

        if (dt > 0) {
            uint128 d = debt;
            uint128 r0 = rac;

            uint256 d0 = Math.mul(d, r0);
            // TODO: invariant r >= 1
            uint128 r = Math.pow(rate - W, uint128(dt));
            uint128 r1 = Math.u128(Math.mul(r0, r) / uint256(W));
            uint256 d1 = Math.mul(d, r1);
            // y = d * (r1 - r0)
            //   = d * (r0 * r - r0)
            //   = d * r0 * (r - 1)
            // g = y / d0
            //   = r - 1
            uint128 g = r - W;

            pac = Math.u128(Math.mul(pac, r - W) / uint256(W));
            rac = r1;
            last = t;
        }
        // Sync debt
        // Sync lender yield
    }

    function mint(uint128 amt, address dst) external {
        sync();
    }

    function burn(uint128 s) external {}
}
/*
using SafeTransfer for IERC20;

struct Cdp {
    // 1e18
    uint128 gem;
    // Normalized debt (1e18?)
    uint128 debt;
}

IOracle public immutable oracle;
// IRateController public immutable ctrl;

uint128 public coin_in;
uint128 public coin_out;

// Borrow rate accumulator
uint128 public racc;
// Lending yield rate accumulator
uint128 public yacc;

// Total lender shares
// total coin with interest = yacc * pie
uint128 public pie;
mapping(address => uint128) public shares;

mapping(address => Cdp) public cdps;

constructor(address _gem, address _coin, address _oracle, address _ctrl) {
    // TODO: combine (join + decimal normalization)
    gem = IERC20(_gem);
    coin = IERC20(_coin);
    oracle = IOracle(_oracle);
    // ctrl = IRateController(_ctrl);
    racc = W;
    rate = W;
    last = block.timestamp;
}

function calc() public view returns (uint128) {
    return racc * Math.pow(rate, block.timestamp - last) / W;
}

function sync() public returns (uint128 a) {
    // TODO: protocol fee
    // TODO: util rate
    if (block.timestamp > last) {
        a = calc();
        racc = a;
        last = block.timestamp;
    }
}

function mint(uint128 c) external returns (uint256 s) {
    uint256 a = sync();

    coin.safeTransferFrom(msg.sender, address(this), c);
    coin_in += c;

    uint256 s = c * W / a;
    pie += s;
    shares[msg.sender] += s;

    // TODO: update rates
}

function burn(uint128 s) external returns (uint128 c) {
    uint256 a = sync();

    pie -= s;
    shares[msg.sender] -= s;

    uint256 c = s * a / W;
    coin_in -= c;
    coin.safeTransfer(msg.sender, c);

    // TODO: update rates
}

function transfer(address dst, uint256 s) external {
    uint128 s = Math.u128(s);
    shares[msg.sender] -= s;
    shares[dst] += s;
}

function poke() public returns (uint128) {
    (bool ok, uint128 price) = oracle.poke(address(gem), address(coin));
    require(ok, "oracle not ok");
    return price;
}

function lock(uint128 g) external {
    gem.safeTransferFrom(msg.sender, address(this), g);
    cdps[msg.sender].gem += g;
}

function unlock(uint128 g) external {
    uint128 a = sync();

    Cdp memory cdp = cdps[msg.sender];
    cdp.gem -= g;

    uint128 p = poke();
    require(mul(cdp.debt, a) < mul(cdp.gem, p));

    cdps[msg.sender].gem -= g;
    gem.safeTransfer(msg.sender, g);
}

function borrow(uint128 d) external {
    uint128 a = sync();

    Cdp memory cdp = cdps[msg.sender];
    cdp.debt += d;

    uint128 p = poke();
    require(a * cdp.debt < cdp.gem * p);

    uint256 c = a * d / W;
    coin_out += c;
    coin_out <= coin_in
    coin.safeTransfer(msg.sender, c);

    // TODO: update rates
}

function repay(uint128 c) external {
    uint256 a = sync();
}

function flash(uint128 c, uint128 g) external {}
function liquidate() external {}
*/

