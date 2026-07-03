// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

contract Auth {
    event Allow(address indexed usr);
    event Deny(address indexed usr);

    mapping(address => bool) public auths;

    modifier auth() {
        require(auths[msg.sender], "not auth");
        _;
    }

    constructor() {
        auths[msg.sender] = true;
        emit Allow(msg.sender);
    }

    function allow(address usr) external auth {
        auths[usr] = true;
        emit Allow(usr);
    }

    function deny(address usr) external auth {
        auths[usr] = false;
        emit Deny(usr);
    }
}
