// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./lib/IERC20.sol";
import {Math} from "./lib/Math.sol";

interface IVault {
    function deposit(uint128 amt) external;
    function withdraw(uint128 amt) external returns (uint128);
    function claim() external returns (uint128);
}

contract DCA {
    // TODO: lock
    IERC20 public immutable sell;
    IERC20 public immutable buy;
    IVault public immutable vault;

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
    mapping(address => uint128) public vs;

    constructor(address _sell, address _buy, address _vault) {
        require(_sell != _buy, "sell = buy");
        sell = IERC20(_sell);
        buy = IERC20(_buy);

        // Optional
        vault = IVault(_vault);
        if (address(vault) != address(0)) {
            sell.approve(address(vault), type(uint256).max);
        }
    }

    function sync(address usr) public returns (uint128, uint128) {
        uint128 y;
        if (address(vault) != address(0)) {
            y = vault.claim();
        }

        uint128 tn = t;
        uint128 rn = r;
        uint256 msn = ms;
        uint256 mgn = mg;
        Snap memory s = snaps[usr];

        uint128 v = vs[usr] + Math.v(s.dk, msn, s.msk, s.rk);
        uint128 w = Math.w(s.dk, mgn, s.mgk, s.rk);
        uint128 d = Math.d(s.dk, rn, s.rk) + w;

        mgn = Math.mg(mgn, y, rn, tn);

        s.dk = d;
        s.rk = rn;
        s.msk = msn;
        s.mgk = mgn;
        snaps[usr] = s;
        vs[usr] = v;
        mg = mgn;
        t = tn + w;

        return (d, v);
    }

    function deposit(uint128 amt) external {
        sync(msg.sender);
        snaps[msg.sender].dk += amt;
        t += amt;
        sell.transferFrom(msg.sender, address(this), amt);
        if (address(vault) != address(0)) {
            vault.deposit(amt);
        }
    }

    function withdraw(uint128 amt, uint128 min) external returns (uint128) {
        (uint128 d,) = sync(msg.sender);
        if (amt == type(uint128).max) {
            amt = d;
        }
        snaps[msg.sender].dk -= amt;
        t -= amt;

        if (address(vault) != address(0)) {
            amt = vault.withdraw(amt);
        }
        require(amt >= min, "amt < min");
        sell.transfer(msg.sender, amt);

        return amt;
    }

    function claim() external returns (uint128 v) {
        (, v) = sync(msg.sender);
        vs[msg.sender] = 0;
        buy.transfer(msg.sender, v);
    }

    uint128 public cap;
    uint64 public epoch;

    function swap(uint128 q, uint128 b) external {
        // TODO: DCA logic (time + amount (chunk), oracle)
        uint128 rn = r;
        uint128 tn = t;
        ms = Math.ms(ms, b, rn, tn);
        r = Math.r(rn, q, tn);
        t = tn - q;

        buy.transferFrom(msg.sender, address(this), b);
        // TODO: callback
        sell.transfer(msg.sender, q);
    }
}
