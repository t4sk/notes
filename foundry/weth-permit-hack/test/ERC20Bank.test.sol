// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test} from "forge-std/Test.sol";
import {WETH} from "../src/WETH.sol";
import {ERC20Bank} from "../src/ERC20Bank.sol";
import {ERC20BankExploit} from "../src/ERC20BankExploit.sol";

contract ERC20BankExploitTest is Test {
    WETH private weth;
    ERC20Bank private bank;
    ERC20BankExploit private exploit;
    address private constant user = address(11);
    address private constant attacker = address(12);

    function setUp() public {
        weth = new WETH();
        bank = new ERC20Bank(address(weth));
        exploit = new ERC20BankExploit(address(bank));

        deal(user, 100 * 1e18);
        vm.prank(user);
        weth.deposit{value: 100 * 1e18}();

        vm.prank(user);
        weth.approve(address(bank), type(uint256).max);

        vm.prank(user);
        bank.deposit(1e18);
    }

    function test_pwn() public {
        vm.prank(attacker);
        exploit.pwn(user);

        assertEq(weth.balanceOf(user), 0, "WETH balance of user");
        assertEq(weth.balanceOf(address(exploit)), 99 * 1e18, "WETH balance of exploit");
    }
}
