// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.32;

import {IERC20} from "./lib/IERC20.sol";

contract Vault {
    IERC20 public immutable token;
    // Virtual shares offset (1 token = 10**offset shares)
    uint256 public immutable offset;
    // user => shares
    mapping(address => uint256) public shares;
    // Total shares
    uint256 public pie;

    constructor(address _token, uint256 _offset) {
        token = IERC20(_token);
        offset = _offset;
    }

    function deposit(uint256 amt) external returns (uint256 s) {
        /*
        a = amount of token to deposit
        B = total token balance
        s = shares to mint
        T = total shares

        (B + a) / B = (T + s) / T
        aT = Bs
        s = aT / B
        */
        uint256 bal = token.balanceOf(address(this));

        // This code is vulnerable to inflation attack
        // if (pie == 0) {
        //     s = amt;
        // } else {
        //     s = amt * pie / bal;
        // }

        // +10**offset to virtual shares
        // +1 to virtual token balance
        s = amt * (pie + 10 ** offset) / (bal + 1);
        pie += s;
        shares[msg.sender] += s;
        token.transferFrom(msg.sender, address(this), amt);
    }

    function withdraw(uint256 s) external returns (uint256 amt) {
        /*
        a = amount of token to withdraw
        B = total token balance
        s = shares to burn
        T = total shares

        (B - a) / B = (T - s) / T
        aT = Bs
        a = Bs / T
        */
        uint256 bal = token.balanceOf(address(this));

        // This code is vulnerable to inflation attack
        // amt = s * bal / pie;

        amt = s * (bal + 1) / (pie + 10 ** offset);
        pie -= s;
        shares[msg.sender] -= s;
        token.transfer(msg.sender, amt);
    }
}
