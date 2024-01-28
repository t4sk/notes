// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC20} from "./ERC20.sol";

contract Token is ERC20 {
    constructor(string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals)
    {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
