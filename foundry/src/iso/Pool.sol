// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";

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

uint128 constant WAD = 1e18;
uint128 constant RAY = 1e27;
// 1e18 = 100%
uint128 constant FEE = 0.05e18;
// 1e18 = 100%
uint128 constant FLASH_FEE = 0.001e18;

library Math {
    function u64(uint256 x) internal pure returns (uint64 z) {
        require(x <= type(uint64).max, "x > u64 max");
        z = uint64(x);
    }

    function u128(uint256 x) internal pure returns (uint128 z) {
        require(x <= type(uint128).max, "x > u128 max");
        z = uint128(x);
    }

    function min(uint128 x, uint128 y) internal pure returns (uint128 z) {
        z = x <= y ? x : y;
    }

    function max(uint128 x, uint128 y) internal pure returns (uint128 z) {
        z = x >= y ? x : y;
    }

    // Binomial expansion
    // (1+x)^n = 1+n*x+(n*(n-1)/2)*x^2+[n*(n-1)*(n-2)/6*x^3...
    // TODO: check math
    function pow(uint128 x, uint128 n) internal pure returns (uint128 z) {
        z = RAY + n * x + n * (n - 1) / 2 * x * x / RAY + n * (n - 1) * (n - 2)
            / 6 * x * x / RAY * x / RAY;
    }

    function mul(uint128 x, uint128 y) internal pure returns (uint256 z) {
        z = uint256(x) * uint256(y);
    }

    function muldiv(uint128 x, uint128 y, uint128 d)
        internal
        pure
        returns (uint128 z)
    {
        z = u128(uint256(x) * uint256(y) / uint256(d));
    }
}

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

// TODO: check rate >= 1 and rac > 0

// TODO: ERC20
// TODO: exit queue?
// TODO: round down shares and round up debt?
// TODO: transient lock
// TODO: handle debt rate blow up
contract Pool {
    using SafeTransfer for IERC20;

    struct Cdp {
        // [1e18]
        uint128 gem;
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

    constructor(address g, address c, address o, address r) {
        gem = IERC20(g);
        coin = IERC20(c);
        oracle = IOracle(o);
        ctrl = IRateController(r);
        pot = msg.sender;
        rate = RAY;
        rac = RAY;
        pac = RAY;
        last = Math.u64(block.timestamp);

        uint8 gdec = gem.decimals();
        require(gdec <= 18, "gem decimals > 18");
        uint8 cdec = coin.decimals();
        require(cdec <= 18, "coin decimals > 18");
        gnorm = Math.u128(10 ** (18 - gdec));
        cnorm = Math.u128(10 ** (18 - cdec));
    }

    function sync() public {
        uint64 t = Math.u64(block.timestamp);
        uint64 dt = t - last;

        // TODO: check calling sync twice in the same time stamp doesn't change state variables
        if (dt > 0) {
            uint128 d = debt;
            uint128 r0 = rac;

            uint256 d0 = Math.mul(d, r0);
            // TODO: check r >= 1
            uint128 r = Math.pow(rate - RAY, uint128(dt));
            uint128 r1 = Math.muldiv(r0, r, RAY);
            /* TODO: enforce non decrease?
            r1 = Math.max(r1, r0);
            */
            uint256 d1 = Math.mul(d, r1);
            // y = (d1 - d0) * (1 - F) (TODO: check d1 >= d0)
            //   = d * (r1 - r0) * (1 - F)
            //   = d * (r0 * r - r0) * (1 - F)
            //   = d * r0 * (r - 1) * (1 - F)
            // g = y / d0
            //   = (r - 1) * (1 - F)
            uint128 g = r - RAY;
            uint128 fee = Math.muldiv(g, FEE, WAD);
            uint128 rem = g - fee;

            // TODO: what to do with fee?
            if (fee > 0) {
                // mint fee * d to treasury?
            }

            // TODO: check g > 0 and pac > 0
            // TODO: check rem > 0
            pac = Math.muldiv(pac, rem, RAY);
            rac = r1;
            last = t;
        }
    }

    function post() private {
        // TODO: check rate >= 1
        // uint128 r = ctrl.calc(net, Math.muldiv(debt, rac, RAY));
        // rate = r;
    }

    function mint(uint128 amt, uint128 min) external returns (uint128 slice) {
        sync();

        uint128 wad = amt * cnorm;
        slice = Math.muldiv(wad, RAY, pac);
        require(slice >= min, "slice < min");

        pie += slice;
        slices[msg.sender] += slice;
        net += wad;

        coin.safeTransferFrom(msg.sender, address(this), amt);
        post();
    }

    function burn(uint128 slice, uint128 min) external returns (uint128 amt) {
        sync();

        uint128 wad = Math.muldiv(slice, pac, RAY);
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
        cdps[msg.sender].gem += amt * gnorm;
    }

    function unlock(uint128 amt) external {
        sync();

        Cdp memory cdp = cdps[msg.sender];
        cdp.gem -= amt * gnorm;

        // TODO: price safety margin?
        uint128 p = poke();
        require(Math.mul(cdp.debt, rac) < Math.mul(cdp.gem, p), "unsafe cdp");

        cdps[msg.sender].gem = cdp.gem;
        gem.safeTransfer(msg.sender, amt);
    }

    function borrow(uint128 amt) external {
        sync();

        // TODO: require amt >= min

        Cdp memory cdp = cdps[msg.sender];
        // TODO: check amt / rac > 0
        // Round up?
        uint128 wad = amt * cnorm;
        uint128 d = Math.muldiv(wad, RAY, rac) + 1;
        cdp.debt += d;

        // TODO: price safety margin?
        uint128 p = poke();
        require(Math.mul(cdp.debt, rac) < Math.mul(cdp.gem, p), "unsafe cdp");

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
        uint128 max = Math.muldiv(cdp.debt, rac, RAY) + 1;
        if (amt * cnorm >= max) {
            d = cdp.debt;
            amt = max / cnorm;
        } else {
            d = Math.min(Math.muldiv(amt * cnorm, RAY, rac) + 1, cdp.debt);
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

    function liquidate() external {}

    function flash(uint128 c, uint128 g) external {}

    function donate(uint128 amt) external {
        loss -= amt * cnorm;
        coin.safeTransferFrom(msg.sender, address(this), amt);
    }
    // TODO: pause
    // TODO: emergency recovery
    // TODO: sweep dust to treasury
}
