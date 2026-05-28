// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.32;

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address dst, uint256 amt) external returns (bool);
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
    function approve(address spender, uint256 amt) external returns (bool);
    function transferFrom(address src, address dst, uint256 amt)
        external
        returns (bool);

    // IERC20 metadata
    function decimals() external view returns (uint8);
}

