// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Test, console} from "forge-std/Test.sol";

contract Vault {
    // 1e18
    mapping(address => uint256 shares) public shares;
    // 1e18
    uint256 public totalShares;
    // 1e18
    uint256 public totalValue;

    function deposit(address usr, uint256 amt) external returns (uint256 s) {
        if (totalShares == 0) {
            s = amt;
        } else {
            s = amt * totalShares / totalValue;
        }
        shares[usr] += s;
        totalShares += s;
        totalValue += amt;
    }

    function withdraw(address usr, uint256 s) external returns (uint256 amt) {
        amt = s * totalValue / totalShares;
        shares[usr] -= s;
        totalShares -= s;
        totalValue -= amt;
    }

    function calcShares(uint256 amt) external view returns (uint256 s) {
        if (totalValue == 0) {
            return 0;
        }
        s = amt * totalShares / totalValue;
    }

    function claimable(address usr) external view returns (uint256 amt) {
        if (totalShares == 0) {
            return 0;
        }
        return shares[usr] * totalValue / totalShares;
    }

    function update(int256 delta) external {
        if (delta >= 0) {
            totalValue += uint256(delta);
        } else {
            totalValue -= uint256(-delta);
        }
    }
}

contract Rebase {
    // 1e18
    mapping(address => uint256 shares) public shares;
    // 1e18
    uint256 public totalShares;
    // Growth accumulator [1e18]
    uint256 public acc = 1e18;

    function deposit(address usr, uint256 amt) external returns (uint256 s) {
        s = amt * 1e18 / acc;
        shares[usr] += s;
        totalShares += s;
    }

    function withdraw(address usr, uint256 s) external returns (uint256 amt) {
        amt = s * acc / 1e18;
        shares[usr] -= s;
        totalShares -= s;
    }

    function calcShares(uint256 amt) external view returns (uint256 s) {
        s = amt * 1e18 / acc;
    }

    function claimable(address usr) external view returns (uint256 amt) {
        return shares[usr] * acc / 1e18;
    }

    function totalValue() external view returns (uint256) {
        return totalShares * acc / 1e18;
    }

    // delta [1e18]
    function update(int256 delta) external {
        uint256 p = totalShares * acc / 1e18;
        require(p > 0, "p = 0");

        uint256 g;
        if (delta >= 0) {
            g = (p + uint256(delta)) * 1e18 / p;
        } else {
            g = (p - uint256(-delta)) * 1e18 / p;
        }
        acc = acc * g / 1e18;
    }
}

function min(uint256 x, uint256 y) returns (uint256) {
    return x <= y ? x : y;
}

function diff(uint256 x, uint256 y) returns (uint256) {
    return x >= y ? x - y : y - x;
}

contract Handler is Test {
    Vault vault;
    Rebase rebase;
    address[] users;

    constructor(address v, address r, address[] memory _users) {
        vault = Vault(v);
        rebase = Rebase(r);
        users = _users;
    }

    function deposit(uint256 seed, uint256 amt) external {
        address usr = users[bound(seed, 0, users.length - 1)];

        amt = bound(amt, 0, 1000 * 1e18);
        console.log("deposit", amt);
        vault.deposit(usr, amt);
        rebase.deposit(usr, amt);
    }

    function withdraw(uint256 seed, uint256 amt) external {
        address usr = users[bound(seed, 0, users.length - 1)];

        amt = bound(amt, 0, 1000 * 1e18);
        amt = min(amt, vault.claimable(usr));
        amt = min(amt, rebase.claimable(usr));

        if (vault.totalShares() > 0) {
            console.log("withdraw", amt);
            vault.withdraw(usr, vault.calcShares(amt));
            rebase.withdraw(usr, rebase.calcShares(amt));
        }
    }

    function update(int256 val) external {
        console.log("vault", vault.totalValue(), "rebase", rebase.totalValue());
        uint256 m = min(vault.totalValue(), rebase.totalValue());
        if (m == 0) {
            return;
        }

        val = bound(val, -int256(m), int256(m));
        console.log("update", val);
        vault.update(val);
        rebase.update(val);
    }
}

contract VaultAndRebaseTest is Test {
    Vault vault;
    Rebase rebase;
    address[] users = [address(1), address(2), address(3)];
    Handler handler;

    function setUp() public {
        vault = new Vault();
        rebase = new Rebase();
        handler = new Handler(address(vault), address(rebase), users);
        targetContract(address(handler));
    }

    function test() public {
        for (uint256 i = 0; i < 100; i++) {
            uint256 action = vm.randomUint() % 3;
            if (action == 0) {
                uint256 seed = vm.randomUint();
                uint256 amt = vm.randomUint();
                handler.deposit(seed, amt);
            } else if (action == 1) {
                uint256 seed = vm.randomUint();
                uint256 amt = vm.randomUint();
                handler.withdraw(seed, amt);
            } else {
                int256 val = vm.randomInt();
                handler.update(val);
            }

            uint256 v = vault.totalValue();
            uint256 r = rebase.totalValue();
            uint256 vc = vault.claimable(users[0]);
            uint256 rc = rebase.claimable(users[0]);
            uint256 d = diff(v, r);
            uint256 dc = diff(vc, rc);
            console.log("---------------------");
            console.log("total:", v, r);
            console.log("total diff:", d);
            console.log("claimable:", vc, rc);
            console.log("claimable diff:", dc);
            console.log("---------------------");
        }
    }

    /*
    function invariant_pool_value() public view {
        assertApproxEqAbs(vault.totalValue(), rebase.totalValue(), 0.001 * 1e18);
    }
    */
}
