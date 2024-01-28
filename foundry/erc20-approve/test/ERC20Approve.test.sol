// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {Test, console2} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";

contract ERC20ApproveTest is Test {
    Token private token;
    address private constant owner = address(11);
    address private constant spender = address(12);

    function setUp() public {
        token = new Token("token", "TOKEN", 18);
        token.mint(owner, 2000);
    }

    // Front run ERC20 approve
    // 1. Owner approves 1000 
    // 2. Spender spend 1000
    // 3. Owner updates approval to 100
    // 4. Spender spend 100
    function test() public {
        // Owner approves 1000
        vm.prank(owner);
        token.approve(spender, 1000);

        // Spender spends 1000
        vm.prank(spender);
        token.transferFrom(owner, spender, 1000);

        // Owner updates approval to 100
        vm.prank(owner);
        token.approve(spender, 100);

        // Spender spends 100
        vm.prank(spender);
        token.transferFrom(owner, spender, 100);

        console2.log("spender balance", token.balanceOf(spender));
    }
}
