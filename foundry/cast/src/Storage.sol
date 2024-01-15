// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

contract Storage {
    uint256 public val;

    function set(uint256 _val) external {
        val = _val;
    }
}
