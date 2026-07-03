// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";
import {Math} from "../lib/Math.sol";
import {Auth} from "../lib/Auth.sol";

contract Stake is Auth {
    using SafeTransfer for IERC20;

    event Deposit(address indexed usr, uint256 amt);
    event Withdraw(address indexed usr, uint256 amt);
    event Take(address indexed usr, uint256 amt);
    event Refund(address indexed usr, uint256 amt);
    event Restake(address indexed usr, uint256 amt);
    event Inc(uint256 amt);
    event Roll(uint256 rate);
    event Stop();
    event Settle(uint256 state);
    event Cover(uint256 amt);
    event Exit(address indexed usr, uint256 amt);

    // Rate scale
    uint256 private constant R = 1e9;
    IERC20 public immutable token;
    // Reward duration
    uint256 public immutable dur;
    // Minimum amount to deposit and must remain in stake
    uint256 public immutable dust;
    // Target coverage
    // Total rewards paid in a duration <= min(total reward allocated in duration, max total staked / cov)
    uint256 public immutable cov;

    enum State {
        Live,
        Stopped,
        Cover,
        Exit
    }

    State public state;

    // Total staked
    uint256 public total;
    // user => staked amount
    mapping(address usr => uint256 amt) public shares;

    // Last updated time
    uint256 public last;
    // Expiration time
    uint256 public exp;
    // Rate of token emission per second
    uint256 public rate;
    // Rate accumulator
    uint256 public acc;
    // User => last rate accumulator
    mapping(address usr => uint256 acc) public accs;
    mapping(address usr => uint256 amt) public rewards;

    // Next rate
    uint256 public nextRate;
    // Timestamp to apply next rate
    uint256 public next;
    // Authorized account to call roll
    address public insuree;

    // Rewards remaining after stop
    uint256 public keep;
    // Total amount of rewards deposited
    uint256 public topped;
    // Total amount of rewards claimed (transferred out or restaked)
    uint256 public paid;

    modifier live() {
        require(state == State.Live, "not live");
        require(block.timestamp < exp, "expired");
        _;
    }

    constructor(
        address _token,
        address _insuree,
        uint256 _dur,
        uint256 _dust,
        uint256 _cov
    ) {
        token = IERC20(_token);
        insuree = _insuree;
        dur = _dur;
        dust = _dust;
        cov = _cov;
        state = State.Live;
        last = block.timestamp;
        exp = block.timestamp + _dur;

        require(cov >= 1 && cov <= 1000, "invalid cov");
        // Check cap() > 0 when tot > 0
        require(dust * R >= cov * dur, "dust < cov * dur");

        // Insuree can reclaim rewards while no one staked
        // Some calculations are done with total + 1 to account for this share
        shares[address(this)] = 1;
    }

    function stopped() external view returns (bool) {
        return state != State.Live;
    }

    // Remaining rewards
    function pot() public view returns (uint256 rem) {
        if (exp <= block.timestamp) {
            return 0;
        }
        if (next > 0) {
            if (block.timestamp < next) {
                rem = rate * (next - block.timestamp) / R;
                rem += nextRate * dur / R;
            } else if (block.timestamp < exp) {
                rem = nextRate * (exp - block.timestamp) / R;
            }
        } else {
            if (block.timestamp < exp) {
                rem = rate * (exp - block.timestamp) / R;
            }
        }
    }

    // Cap on rate.
    // a = total reward allocated for the duration
    // If total staked <= cov * a
    // then total rewards paid <= total staked / cov
    // Let c = cap
    // sum(c * dt) <= sum(r * dt) <= a
    // if total <= cov * a for the whole duration
    // total / cov / dur <= a / dur <= rate, since rate always increases after inc()
    // sum(c * dt) <= total / cov / dur * sum(dt) = total / cov
    function cap(uint256 r, uint256 tot) private view returns (uint256) {
        return Math.min(r, tot * R / (cov * dur));
    }

    // Calculate claimable rewards of a user
    function calc(address usr) external view returns (uint256) {
        // Cap timestamp to exp
        uint256 t = Math.min(block.timestamp, exp);
        uint256 a = acc;
        uint256 tot = total;
        if (next > 0 && next <= t) {
            a += cap(rate, tot) * (next - last) / (tot + 1);
            a += cap(nextRate, tot) * (t - next) / (tot + 1);
        } else {
            a += cap(rate, tot) * (t - last) / (tot + 1);
        }
        return rewards[usr] + shares[usr] * (a - accs[usr]) / R;
    }

    // Sync rewards
    function sync(address usr) public returns (uint256 amt) {
        // Cap timestamp to exp
        uint256 t = Math.min(block.timestamp, exp);
        uint256 a = acc;
        uint256 tot = total;
        // Save excess for insuree
        uint256 saved = 0;

        if (next > 0 && next <= t) {
            uint256 r = rate;
            uint256 c = cap(r, tot);
            uint256 dt = next - last;
            a += c * dt / (tot + 1);
            saved += (r - c) * dt / R;

            last = next;
            rate = nextRate;
            nextRate = 0;
            next = 0;
        }

        uint256 r = rate;
        uint256 c = cap(r, tot);
        uint256 dt = t - last;
        a += c * dt / (tot + 1);
        saved += (r - c) * dt / R;

        acc = a;
        last = t;

        if (saved > 0) {
            keep += saved;
        }

        if (usr != address(0)) {
            amt = shares[usr] * (a - accs[usr]) / R;
            accs[usr] = a;
            rewards[usr] += amt;
        }
    }

    function deposit(uint256 amt) external live {
        require(amt >= dust, "dust");
        token.safeTransferFrom(msg.sender, address(this), amt);
        sync(msg.sender);
        total += amt;
        shares[msg.sender] += amt;
        emit Deposit(msg.sender, amt);
    }

    function withdraw(address usr, address dst, uint256 amt)
        external
        auth
        live
    {
        require(usr != address(this), "invalid usr");
        sync(usr);
        total -= amt;
        shares[usr] -= amt;
        require(shares[usr] == 0 || shares[usr] >= dust, "dust");
        token.safeTransfer(dst, amt);
        emit Withdraw(usr, amt);
    }

    // Claim rewards
    function take() public returns (uint256 amt) {
        sync(msg.sender);
        amt = rewards[msg.sender];
        if (amt > 0) {
            rewards[msg.sender] = 0;
            paid += amt;
            token.safeTransfer(msg.sender, amt);
        }
        emit Take(msg.sender, amt);
    }

    // Restake rewards
    function restake() external live returns (uint256 amt) {
        sync(msg.sender);
        amt = rewards[msg.sender];
        if (amt > 0) {
            rewards[msg.sender] = 0;
            paid += amt;
            total += amt;
            shares[msg.sender] += amt;
            require(shares[msg.sender] >= dust, "dust");
        }
        emit Restake(msg.sender, amt);
    }

    // Refund to insuree
    function refund() external returns (uint256 amt) {
        require(msg.sender == insuree, "not insuree");

        sync(address(this));
        amt = rewards[address(this)];
        if (amt > 0) {
            rewards[address(this)] = 0;
            paid += amt;
        }

        if (keep > 0) {
            amt += keep;
            paid += keep;
            keep = 0;
        }

        if (amt > 0) {
            token.safeTransfer(msg.sender, amt);
        }
        emit Refund(msg.sender, amt);
    }

    // Increase reward emission rate
    function inc(uint256 amt) external live {
        sync(address(0));
        token.safeTransferFrom(msg.sender, address(this), amt);

        uint256 t = next > 0 ? next : exp;
        uint256 delta = amt / (t - block.timestamp);
        require(delta > 0, "delta rate = 0");
        rate += delta * R;
        topped += amt;

        emit Inc(amt);
    }

    // Extend insurance and schedule new rate
    function roll(uint256 r) external live {
        require(msg.sender == insuree, "not insuree");
        require(rate > 0, "rate = 0");
        require(next == 0, "rolled");
        // Allow rolling when time remaining is < half the duration
        require(exp - block.timestamp < dur / 2, "too early");

        sync(address(0));
        if (r > 0) {
            uint256 amt = r * dur;
            token.safeTransferFrom(msg.sender, address(this), amt);
            topped += amt;
        }

        nextRate = r * R;
        next = exp;
        exp += dur;

        emit Roll(r);
    }

    // Stop reward emissions
    function stop() external auth live {
        sync(address(0));
        keep += pot();
        exp = block.timestamp;
        state = State.Stopped;
        emit Stop();
    }

    // Decide who to pay (insuree or stakers)
    function settle(State s) external auth {
        require(state == State.Stopped, "not stopped");
        require(s == State.Cover || s == State.Exit, "invalid next state");
        state = s;
        emit Settle(uint256(s));
    }

    // Pay insuree
    function cover(address dst, uint256 amt) external auth returns (uint256) {
        require(state == State.Cover, "invalid state");
        require(dst != address(0), "dst = 0");

        if (amt > 0) {
            token.safeTransferFrom(msg.sender, address(this), amt);
        }

        amt += total;
        total = 0;

        token.safeTransfer(dst, amt);

        emit Cover(amt);
        return amt;
    }

    // Pay stakers
    function exit() external returns (uint256 amt) {
        // Expired without call to stop or settled
        if (state == State.Live) {
            require(exp < block.timestamp, "not expired");
        } else {
            require(state == State.Exit, "invalid state");
        }

        sync(msg.sender);

        // Rewards
        uint256 r = rewards[msg.sender];
        rewards[msg.sender] = 0;
        paid += r;

        // Staked
        uint256 s = shares[msg.sender];
        shares[msg.sender] = 0;
        total -= s;

        amt = r + s;

        token.safeTransfer(msg.sender, amt);

        emit Exit(msg.sender, amt);
    }

    function recover(address _token) external auth {
        if (_token == address(0)) {
            (bool ok,) = msg.sender.call{value: address(this).balance}("");
            require(ok, "send ETH failed");
        } else if (_token == address(token)) {
            uint256 bal = token.balanceOf(address(this));
            // topped >= paid
            // topped - paid = future reward emissions + rewards claimable by stakers
            // bal >= staked + topped - paid
            uint256 need = total + topped - paid;
            token.safeTransfer(msg.sender, bal - need);
        } else {
            uint256 bal = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(msg.sender, bal);
        }
    }
}
