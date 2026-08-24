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
// TODO: treasury

contract Pool {
    using SafeTransfer for IERC20;

    IERC20 public immutable gem;
    IERC20 public immutable coin;
    IOracle public immutable oracle;
    // IRateController public immutable ctrl;

    // Underlying balance
    uint128 public bal;

    uint128 public acc;
    uint128 public rate;
    uint64 public last;

    uint128 public pie;
    mapping(address => uint128) public shares;

    constructor(address _gem, address _coin, address _oracle, address _ctrl) {
        // TODO: combine (join + decimal normalization)
        gem = IERC20(_gem);
        coin = IERC20(_coin);
        oracle = IOracle(_oracle);
        // ctrl = IRateController(_ctrl);
        acc = W;
        rate = W;
        last = block.timestamp;
    }

    function calc() public view returns (uint128) {
        return acc * Math.pow(rate, block.timestamp - last) / W;
    }

    function sync() public returns (uint128 a) {
        // TODO: protocol fee
        // TODO: util rate
        if (block.timestamp > last) {
            a = calc();
            acc = a;
            last = block.timestamp;
        }
    }

    function mint(uint128 c) external returns (uint256 s) {
        uint256 a = sync();

        coin.safeTransferFrom(msg.sender, address(this), c);
        bal += c;

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
        bal -= c;
        coin.safeTransfer(msg.sender, c);

        // TODO: update rates
    }

    function transfer(address dst, uint256 s) external {
        uint128 s = Math.u128(s);
        shares[msg.sender] -= s;
        shares[dst] += s;
    }

    struct Cdp {
        // 1e18
        uint128 gem;
        // Normalized debt (1e18?)
        uint128 debt;
    }

    mapping(address => Cdp) public cdps;

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
        bal -= c;
        coin.safeTransfer(msg.sender, c);

        // TODO: update rates
    }

    function repay(uint128 c) external {
        uint256 a = sync();
    }

    function flash(uint128 c, uint128 g) external {}
    function liquidate() external {}
}
