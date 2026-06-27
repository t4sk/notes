// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// TODO: ROCQ

// T[i] = total deposit at time i
// Q[i] = deposit deducted at time i
// D[i] = user's deposit after deduction at time i
//      = D[i - 1] - Q[i] * D[i - 1] / T[i - 1]

// User deposits at time K < N
// D[N] = D[K] * P[N] / P[K]

// P[0] = 1
// P[N] = prod(1 - Q[i] / T[i - 1]) for 1 <= i <= N

// C[i] = collateral seized at time i
// V[N] = user's claim on collateral at time N
//      = C[K + 1] * D[K] / T[K] + ... + C[N] * D[N - 1] / T[N - 1]
//      = D[K] * (S[N] - S[K]) / P[K]

// S[0] = 0
// S[N] = sum(C[i] / T[i - 1] * P[i - 1]) for 1 <= i <= N

// M = u128 max
// R[N] = reduction factor at time N
// R[0] = 0
// R[N] = M - (M - R[N - 1]) * (1 - Q[N] / T[N - 1])
//             128 bits        128 bits

// M - R[N] = (M - R[N - 1]) * (1 - Q[N] / T[N - 1])
// M - R[N] = M * P[N]

// M - R[N] <= 128 bits
// M * S[N] = sum(C[i] / T[i - 1] * (M - R[i - 1])) for 1 <= i <= N
// M * S[N] <= 256 bits

// D[N] = D[K] * P[N] / P[K]
//      = D[K] * (M - R[N]) / (M - R[K])
//      <= 256 bits

// V[N] = D[K] * (S[N] - S[K]) / P[K]
//      = D[K] * M * (S[N] - S[K]) / (M - R[K])
//      <= 128 + 256 bits

uint256 constant M = type(uint128).max;

library Math {
    function u128(uint256 u) internal pure returns (uint128) {
        require(u <= type(uint128).max, "u > u128 max");
        return uint128(u);
    }

    // M * S[N + 1]
    function ms(uint256 msn, uint128 c, uint128 rn, uint256 t)
        internal
        pure
        returns (uint256)
    {
        // TODO: overflow? use muldiv?
        return msn + c * (M - rn) / t;
    }

    // R[N + 1]
    function r(uint256 rn, uint256 q, uint256 t)
        internal
        pure
        returns (uint128)
    {
        // TODO: overflow?
        // TODO: t = 0?
        return u128(M - (M - rn) * (t - q) / t);
    }

    // D[N + 1]
    function d(uint256 dk, uint256 rn, uint256 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: M - rk = 0?
        return u128(dk * (M - rn) / (M - rk));
    }

    // V[N + 1]
    function v(uint256 dk, uint256 msn, uint256 msk, uint256 rk)
        internal
        pure
        returns (uint128)
    {
        // TODO: use muldiv
        // TODO: M - rk = 0?
        return u128(dk * (msn - msk) / (M - rk));
    }

    function muldiv(uint256 x, uint256 y, uint256 d)
        internal
        pure
        returns (uint256)
    {
        // TODO:
        return x * y / d;
    }
}

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

contract DCA is Auth {
    // IERC20 public immutable sell;
    // IERC20 public immutable buy;

    // T[N]
    uint128 public t;
    // R[N]
    uint128 public r;
    // M * S[N]
    uint256 public ms;

    struct Snap {
        uint128 dk;
        uint128 rk;
        uint256 msk;
    }

    mapping(address => Snap) public snaps;
    mapping(address => uint128) public vs;

    function sync(address usr) public returns (uint128 dn, uint128 v) {
        Snap memory s = snaps[usr];
        uint256 rn = r;
        uint256 msn = ms;
        dn = Math.d(s.dk, rn, s.rk);
        v = vs[usr] + Math.v(s.dk, msn, s.msk, s.rk);
        s.dk = dn;
        vs[usr] = v;
        s.rk = uint128(rn);
        s.msk = uint128(msn);
        snaps[usr] = s;
    }

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
        vs[msg.sender] = 0;
    }

    function swap(uint128 q, uint128 c) external auth {
        // TODO: DCA logic (time + amount)
        uint128 rn = r;
        ms = Math.ms(ms, c, rn, t);
        r = Math.r(rn, q, t);
    }
}
