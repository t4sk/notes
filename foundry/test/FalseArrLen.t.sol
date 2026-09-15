// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";

contract FalseArrLenTest is Test {
    function f(uint256 len) public pure returns (uint256[] memory arr) {
        assembly {
            arr := mload(0x40)
            mstore(arr, len)
            // Reserve the fake length by moving free mem pointer
            mstore(0x40, add(arr, 32))
        }
    }

    function test() public {
        // Internal call works
        uint256[] memory arr = f(type(uint256).max);

        // External call reverts (out of gas)
        // uint256[] memory arr = this.f(type(uint256).max);

        // console.log writes to same memory as arr
        // if free mem pointer was not updated
        // so store length in a new variable
        uint256 len = arr.length;
        console.log("arr length:", len);
    }
}

