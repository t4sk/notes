// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "./lib/IERC20.sol";
import {SafeTransfer} from "./lib/SafeTransfer.sol";
import {Math} from "./lib/Math.sol";
import {Auth} from "./Auth.sol";

interface IVault {
    function deposit(uint128 amt) external;
    function withdraw(uint128 amt) external returns (uint128);
    function claim() external returns (uint128);
}

interface IOracle {
    // price = [sell token decimals] / [buy token decimals] * 1e18
    function get(address sell, address buy)
        external
        returns (bool ok, uint256 price, uint256 timestamp);
}

interface ISwap {
    function swap(
        address tokenIn,
        address tokenOut,
        uint128 amountIn,
        uint256 minAmountOut
    ) external;
}

contract DCA is Auth {
    using SafeTransfer for IERC20;

    IERC20 public immutable sell;
    IERC20 public immutable buy;
    IVault public immutable vault;
    IOracle public immutable oracle;

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

    // Rate limit
    // Upper limit of cap
    uint128 public max;
    // Total deposit is divided by this constant to calculate the cap
    uint128 private constant C = 8;
    // Max swap amount per epoch
    uint128 public cap;
    // Swapped amount in the current epoch
    uint128 public curr;
    // Epoch duration
    uint256 private constant E = 7 days;
    uint256 public epoch = (block.timestamp / E) * E;

    // Oracle
    uint256 private constant MAX_PRICE_DT = 5 minutes;
    uint256 private constant MAX_PRICE_DELTA = 0.02e18;

    bool transient locked;

    modifier lock() {
        require(!locked, "locked");
        locked = true;
        _;
        locked = false;
    }

    constructor(address _sell, address _buy, address _oracle, address _vault) {
        require(_sell != _buy, "sell = buy");
        sell = IERC20(_sell);
        buy = IERC20(_buy);

        oracle = IOracle(_oracle);

        // Optional
        vault = IVault(_vault);
        if (address(vault) != address(0)) {
            sell.approve(address(vault), type(uint256).max);
        }
    }

    function set(uint128 val) external auth {
        max = val;
    }

    function sync(address usr) public lock returns (uint128, uint128) {
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

    function deposit(uint128 amt) external lock {
        sync(msg.sender);
        snaps[msg.sender].dk += amt;

        t += amt;
        cap = Math.min(t / C, max);

        sell.safeTransferFrom(msg.sender, address(this), amt);
        if (address(vault) != address(0)) {
            vault.deposit(amt);
        }
    }

    function withdraw(uint128 amt, uint128 min)
        external
        lock
        returns (uint128)
    {
        (uint128 d,) = sync(msg.sender);
        if (amt == type(uint128).max) {
            amt = d;
        }
        snaps[msg.sender].dk -= amt;

        t -= amt;
        cap = Math.min(t / C, max);

        if (address(vault) != address(0)) {
            amt = vault.withdraw(amt);
        }
        require(amt >= min, "amt < min");
        sell.safeTransfer(msg.sender, amt);

        return amt;
    }

    function claim() external lock returns (uint128 v) {
        (, v) = sync(msg.sender);
        vs[msg.sender] = 0;
        buy.safeTransfer(msg.sender, v);
    }

    function swap(uint128 q, uint128 b) external lock {
        if (epoch + E <= block.timestamp) {
            epoch = (block.timestamp / E) * E;
            curr = 0;
        }

        require(curr + q <= cap, "cap");
        curr += q;

        // Oracle check
        (bool ok, uint256 price, uint256 timestamp) =
            oracle.get(address(sell), address(buy));
        require(ok, "oracle not ok");
        require(price > 0, "price = 0");
        require(timestamp <= block.timestamp, "timestamp > block.timestamp");
        require(block.timestamp - timestamp <= MAX_PRICE_DT, "stale price");
        // price = sell token amount / 1 buy token * 1e18
        require(
            uint256(q) * 1e18 / b >= price * (1e18 - MAX_PRICE_DELTA) / 1e18,
            "swap price < oracle price"
        );

        uint128 rn = r;
        uint128 tn = t;
        ms = Math.ms(ms, b, rn, tn);
        r = Math.r(rn, q, tn);
        t = tn - q;

        // Swap
        sell.safeTransfer(msg.sender, q);

        uint256 bal0 = buy.balanceOf(address(this));
        if (msg.sender.code.length > 0) {
            ISwap(msg.sender).swap(address(sell), address(buy), q, b);
        } else {
            buy.safeTransferFrom(msg.sender, address(this), b);
        }
        uint256 bal1 = buy.balanceOf(address(this));
        require(bal1 - bal0 >= b, "buy transfer < min");
    }
}

