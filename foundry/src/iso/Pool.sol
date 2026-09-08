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

uint256 constant W = 1e18;

library Math {
    function u128(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, "x > u128 max");
        return uint128(x);
    }

    function mul(uint128 x, uint128 y) internal pure returns (uint256) {
        return uint256(x) * uint256(y);
    }

    // Binomial expansion
    // (1+x)^n = 1+n*x+(n*(n-1)/2)*x^2+[n*(n-1)*(n-2)/6*x^3...
    function pow(uint128 x, uint128 n) internal pure returns (uint128) {
        return W + n * x + n * (n - 1) / 2 * x * x / W + n * (n - 1) * (n - 2)
            / 6 * x * x / W * x / W;
    }
}

// TODO: stop and withdraw?
// TODO: liq amm = oracle?
// TODO: ERC20
// TODO: fee on transfer and rebase?
// TODO: join adapters to normalize to 18 decimals?
// TODO: protcol + treasury fee split
// TODO: sync balance -> protocol yield


// Total debt with interest = borrow rate acc * total normalized debt
// Utilization rate = total debt with interest / total coin supplied
// borrow rate <- f(utilization rate)

// TODO: check off by 1 miscalculation

// pre = calculation to be done before state updates
// post = calculation to be done after state updates

// Borrow rates
// r[i] = borrow rate for time t,  i <= t < i + 1

// User borrows x at t = K, debt at t = K + N (pre)
// = x * (1 + r[K]) * (1 + r[K + 1]) * ... * (1 + r[K + N - 1])

// Borrow rate accumulator
// R[-1] = 1
// R[N] = (1 + r[-1]) * (1 + r[0]) * (1 + r[1]) * ... * (1 + r[N])

// User's debt = x * R[K + N - 1] / R[K - 1] (pre)

// Normalized debt
// User borrows x0 at time K, borrows or repays x1 at time K + N, debt at time K + M (0 <= N <= M)
// = (x0 * R[K + N - 1] / R[K - 1] + x1) * R[K + M - 1] / R[K + N - 1]
// = (x0 / R[K - 1] + x1 / R[K + N - 1]) * R[K + M - 1]
//   |____________________________|
//            normalized debt
// d' = normalized debt
// D' = total normalized debt
// D = total debt
//   = D' * R[N - 1] at time N (pre)

// -----

// S[k] = Total normalized debt at time k
// D[k] = Total debt at time k
// Total debt from time k to k + N + 1 when S[i] is constant for k <= i <= k + N + 1
// D[k + N + 1] = S[k] * R[k + N]
//              = S[k + N + 1] * R[k + N]

// Total yield between time k and k + N + 1 when S[i] is constant
// y = D[k + N + 1] - D[k]
//   = S[k] * (R[k + N] - R[k - 1])

// Yield split
// F = protocol fee
// y * F = protocol yield
// y * (1 - F) = lender yield

// Yield accumulator
// L[i] = total lender shares at time i
// y[i] = yield between time i - 1 to i
// Y[N] = y[0] / L[0] + y[1] / L[1] + ... + y[N] / L[N] (if L[i] > 0)

// l[i] = lender share at time i
// w[i] = lender max withdrawable balance
// w[i] = l[k] * (Y[k + N + 1] - Y[k])

// TODO:
// Lender yield
// P = total lender yield
// yield growth = (P + y) / P = 1 + y / P
// given initial deposit x at time k, total claimable at time k + N
// x(1 + y[k + 1]/P[k + 1])....(1 + y[k + N - 1]/P[k + N - 1])
// P = T * G

contract Pool {
    using SafeTransfer for IERC20;

    struct Cdp {
        // 1e18
        uint128 gem;
        // Normalized debt (1e18?)
        uint128 debt;
    }

    IERC20 public immutable gem;
    IERC20 public immutable coin;
    IOracle public immutable oracle;
    // IRateController public immutable ctrl;

    uint128 public coin_in;
    uint128 public coin_out;

    // Borrow rate accumulator
    uint128 public bacc;
    // Lending rate accumulator
    uint128 public lacc;
    uint128 public rate;
    uint64 public last;

    // Total lender shares
    // total coin with interest = lacc * pie
    uint128 public pie;
    mapping(address => uint128) public shares;

    mapping(address => Cdp) public cdps;
    // Total normalized debt
    // total debt with interest = bacc * debt
    uint128 public debt;

    constructor(address _gem, address _coin, address _oracle, address _ctrl) {
        // TODO: combine (join + decimal normalization)
        gem = IERC20(_gem);
        coin = IERC20(_coin);
        oracle = IOracle(_oracle);
        // ctrl = IRateController(_ctrl);
        bacc = W;
        rate = W;
        last = block.timestamp;
    }

    function calc() public view returns (uint128) {
        return bacc * Math.pow(rate, block.timestamp - last) / W;
    }

    function sync() public returns (uint128 a) {
        // TODO: protocol fee
        // TODO: util rate
        if (block.timestamp > last) {
            a = calc();
            bacc = a;
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

    /*

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
}
