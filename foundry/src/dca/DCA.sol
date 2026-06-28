// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Math} from "./lib/Math.sol";
import {Auth} from "./Auth.sol";

contract DCA is Auth {
    // IERC20 public immutable sell;
    // IERC20 public immutable buy;

    // T[N]
    uint128 public t;
    // R[N]
    uint128 public r;
    // M * S[N]
    uint256 public ms;
    // M * G[N]
    uint256 public mg;

    struct Snap {
        uint128 dk;
        uint128 rk;
        uint256 msk;
        uint256 mgk;
    }

    mapping(address => Snap) public snaps;
    mapping(address => uint128) public zs;

    function sync(address usr) public returns (uint128, uint128) {
        uint128 y = 0;

        Snap memory s = snaps[usr];
        uint128 tn = t;
        uint128 rn = r;
        uint256 msn = ms;
        uint256 mgn = mg;

        uint128 z = zs[usr] + Math.v(s.dk, msn, s.msk, s.rk);
        uint128 w = Math.w(s.dk, mgn, s.mgk, s.rk);

        mgn = Math.mg(mgn, y, rn, tn);
        uint128 dn = Math.d(s.dk, rn, s.rk) + w;

        t = tn + w;
        s.dk = dn;
        zs[usr] = z;
        s.rk = uint128(rn);
        s.msk = msn;
        s.mgk = mgn;
        snaps[usr] = s;

        return (dn, z);
    }

    // TODO: functionst to deposit sell tokens to earn yield

    function join(uint128 amt) external {
        sync(msg.sender);
        snaps[msg.sender].dk += amt;
        t += amt;
    }

    function exit(uint128 amt) external {
        (uint128 dn,) = sync(msg.sender);
        if (amt == type(uint128).max) {
            amt = dn;
        }
        snaps[msg.sender].dk -= amt;
        t -= amt;
    }

    function claim() external {
        (, uint128 v) = sync(msg.sender);
        zs[msg.sender] = 0;
    }

    function swap(uint128 q, uint128 b) external auth {
        // TODO: DCA logic (time + amount (chunk))
        uint128 rn = r;
        uint128 tn = t;
        ms = Math.ms(ms, b, rn, tn);
        r = Math.r(rn, q, tn);
        t = tn - q;
    }
}
