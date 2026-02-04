// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

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
    // Non-IERC20
    function decimals() external view returns (uint8);
}
