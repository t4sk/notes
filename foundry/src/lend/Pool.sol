// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";

interface IOracle {}

contract Pool {
    IERC20 public immutable gem;
    IERC20 public immutable dai;
    // TODO: liq amm = oracle?
    IOracle public immutable oracle;

    constructor(address _gem, address _dai, address _oracle) {
        gem = IERC20(_gem);
        dai = IERC20(_dai);
        oracle = IOracle(_oracle);
    }

    function mint() external {}
    function burn() external {}
    function deposit() external {}
    function withdraw() external {}
    function borrow() external {}
    function repay() external {}
    function liquidate() external {}
}
