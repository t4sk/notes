// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// TODO: events
contract Auth {
    mapping(address => bool) public auths;

    error NoAuth();

    modifier auth() {
        require(auths[msg.sender], NoAuth());
        _;
    }

    constructor() {
        auths[msg.sender] = true;
    }

    function allow(address usr) external auth {
        auths[usr] = true;
    }

    function deny(address usr) external auth {
        auths[usr] = false;
    }
}

