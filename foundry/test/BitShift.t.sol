// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

contract BitShiftTest is Test {
    function test() public {
        {
            uint256 mask = uint256(1) << 256;
            console.log("1 << 256", mask);
        }
        {
            uint256 mask = type(uint256).max << 1;
            console.logBytes32(bytes32(mask));
            assertEq(mask, type(uint256).max - 1);
        }
    }
}
