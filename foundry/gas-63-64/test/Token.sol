// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {ERC20} from "@src/lib/ERC20.sol";

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals)
    {}

    function mint(address dst, uint256 amt) external {
        _mint(dst, amt);
    }

    function burn(address src, uint256 amt) external {
        _burn(src, amt);
    }
}
