// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";

/*
forge test --ffi --match-path test/Py.sol
*/
contract PyTest is Test {
    function test() public {
        uint256 a = 3;
        uint256 b = 7;

        string[] memory cmd = new string[](3);
        cmd[0] = "py/dev.py";
        cmd[1] = vm.toString(a);
        cmd[2] = vm.toString(b);

        bytes memory result = vm.ffi(cmd);

        (uint256 sum, uint256 prod) = abi.decode(result, (uint256, uint256));

        assertEq(sum, a + b);
        assertEq(prod, a * b);
    }
}
