// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Auth} from "./lib/Auth.sol";

// TODO: ROCQ
contract Core is Auth {
    // Collateral parameters
    struct Col {
        // Total normalized debt
        uint128 tot;
        uint128 rate;
        uint128 spot;
        uint128 max;
        uint128 min;
    }

    // Collateralized debt position
    struct Pos {
        uint128 gem;
        // normalized coin debt
        uint128 norm;
    }

    mapping(bytes32 col => mapping(address usr => uint128 amt)) public gem;
    mapping(bytes32 coin => mapping(address usr => uint128 amt)) public coin;
    mapping(bytes32 coin => mapping(bytes32 col => Col)) public cols;
    mapping(bytes32 coin => mapping(address usr => Pos)) public positions;

    function join(bytes32 col, address usr, uint128 amt) external auth {
        gem[col][usr] += amt;
    }

    function exit(bytes32 col, address usr, uint128 amt) external auth {
        gem[col][usr] -= amt;
    }

    function move(bytes32 col, address src, address dst, uint128 amt) external {
        gem[col][src] -= amt;
        gem[col][dst] += amt;
    }

    function mint() external auth {}

    function burn() external {}

    function transfer() external {}
}
