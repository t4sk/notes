// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

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
        P = total token balance
        s = shares to mint
        T = total shares

        (P + a) / P = (T + s) / T
        a / P = s / T
        s = aT / P (assumming P > 0)
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
        P = total token balance
        s = shares to burn
        T = total shares

        (P - a) / P = (T - s) / T
        a / P = s / T
        a = Ps / T (assuming T > 0)
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
