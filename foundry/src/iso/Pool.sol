// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";

interface IOracle {}

interface IRate {}

uint256 constant W = 1e18;

library Math {
    function u128(uint256 x) internal pure returns (uint128) {
        require(x <= type(uint128).max, "x > u128 max");
        return uint128(x);
    }

    // Binomial expansion
    // (1+x)^n = 1+n*x+(n*(n-1)/2)*x^2+[n*(n-1)*(n-2)/6*x^3...
    function pow(uint256 x, uint256 n) internal pure returns (uint256) {
        return W + n * x + n * (n - 1) / 2 * x * x / W + n * (n - 1) * (n - 2)
            / 6 * x * x / W * x / W;
    }
}

// TODO: stop and withdraw?
// TODO: liq amm = oracle?
// TODO: ERC20
// TODO: fee on transfer and rebase?

contract Pool {
    using SafeTransfer for IERC20;

    IERC20 public immutable gem;
    IERC20 public immutable coin;
    IOracle public immutable oracle;
    // IRate public immutable rate;

    // Underlying balance
    uint128 public bal;

    uint256 public acc;
    uint128 public rate;
    uint64 public last;

    uint128 public pie;
    mapping(address => uint128) public shares;

    constructor(address _gem, address _coin, address _oracle, address _rate) {
        gem = IERC20(_gem);
        coin = IERC20(_coin);
        oracle = IOracle(_oracle);
        // rate = IRate(_rate);
        acc = W;
        rate = W;
        last = block.timestamp;
    }

    function calc() public view returns (uint256) {
        return acc * Math.pow(rate, block.timestamp - last) / W;
    }

    function sync() public returns (uint256 a) {
        if (block.timestamp > last) {
            a = calc();
            acc = a;
            last = block.timestamp;
        }
    }

    function mint(uint128 amt) external returns (uint256 s) {
        uint256 a = sync();

        coin.safeTransferFrom(msg.sender, address(this), amt);
        bal += amt;

        uint256 s = amt * W / a;
        pie += s;
        shares[msg.sender] += s;

        // update rates
    }

    function burn(uint128 s) external returns (uint128 amt) {
        uint256 a = sync();

        pie -= s;
        shares[msg.sender] -= s;

        uint256 amt = s * a / W;
        bal -= amt;
        coin.safeTransfer(msg.sender, amt);

        // update rates
    }

    function transfer(address dst, uint256 s) external {
        uint128 s = Math.u128(s);
        shares[msg.sender] -= s;
        shares[dst] += s;
    }

    // Collateral
    function lock() external {}
    function unlock() external {}

    function borrow() external {}
    function repay() external {}

    function flash() external {}
    function liquidate() external {}
}
