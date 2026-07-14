// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

interface IRebase {
    function transfer(address dst, uint256 amt) external;
    function transferFrom(address src, address dst, uint256 amt) external;
    function calcShares(uint256 underlying)
        external
        view
        returns (uint256 shares);
    function calcUnderlying(uint256 shares)
        external
        view
        returns (uint256 underlying);
}

contract Wrap {
    IRebase public immutable re;
    mapping(address => uint256) public shares;

    constructor(address _re) {
        re = IRebase(_re);
    }

    // Underlying and rebase
    // U = underlying balance
    // R = rebase balance
    // R = U

    // Rebase shares
    // S = rebase internal shares
    // X = rebase rate multiplier
    // R = S * X

    // Rebase and wrap
    // W = wrap shares
    // W = S = R / X

    function wrap(uint256 r) external {
        // W = S = R / X
        uint256 w = re.calcShares(r);
        shares[msg.sender] += w;
        re.transferFrom(msg.sender, address(this), r);
    }

    function unwrap(uint256 w) external {
        // R = S * X = W * X
        uint256 r = re.calcUnderlying(w);
        shares[msg.sender] -= w;
        re.transfer(msg.sender, r);
    }
}
