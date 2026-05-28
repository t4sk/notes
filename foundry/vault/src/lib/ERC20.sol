// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.32;

import {IERC20} from "./IERC20.sol";

contract ERC20 is IERC20 {
    event Transfer(address indexed src, address indexed dst, uint256 amt);
    event Approval(address indexed owner, address indexed spender, uint256 amt);

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    string public name;
    string public symbol;
    uint8 public immutable decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimals) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function transfer(address dst, uint256 amt) external returns (bool) {
        balanceOf[msg.sender] -= amt;
        balanceOf[dst] += amt;
        emit Transfer(msg.sender, dst, amt);
        return true;
    }

    function approve(address spender, uint256 amt) external returns (bool) {
        allowance[msg.sender][spender] = amt;
        emit Approval(msg.sender, spender, amt);
        return true;
    }

    function transferFrom(address src, address dst, uint256 amt)
        external
        returns (bool)
    {
        allowance[src][msg.sender] -= amt;
        balanceOf[src] -= amt;
        balanceOf[dst] += amt;
        emit Transfer(src, dst, amt);
        return true;
    }

    function _mint(address dst, uint256 amt) internal {
        balanceOf[dst] += amt;
        totalSupply += amt;
        emit Transfer(address(0), dst, amt);
    }

    function _burn(address src, uint256 amt) internal {
        balanceOf[src] -= amt;
        totalSupply -= amt;
        emit Transfer(src, address(0), amt);
    }
}

