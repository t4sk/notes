// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {IERC20} from "../lib/IERC20.sol";
import {SafeTransfer} from "../lib/SafeTransfer.sol";

// Swap
// p*dx = dy

// p(i) = 1.0001^i
// X[i] = token X in tick i
// Y[i] = token Y in tick i
// L[i] = liquidity at tick i
//      = p(i) * X[i] + Y[i]

// t = current tick
// For i < t -> L[i] = Y[i]
// For t < i -> L[i] = p(i) * X[i]

uint256 constant RAY_256 = 1e27;

function mul(uint128 x, uint128 y) pure returns (uint256 z) {
    z = uint256(x) * uint256(y);
}

function u128(uint256 x) pure returns (uint128 z) {
    require(x <= type(uint128).max, "x > u128 max");
    z = uint128(x);
}

function pow(uint256 b, uint256 x) pure returns (uint128 z) {}

// TODO: multi token
uint256 constant B = 1.0001 * 1e27;

// TODO: limit order hook
contract Pool {
    using SafeTransfer for IERC20;

    struct Bucket {
        // Normalized coin X amount [1e18]
        uint128 x;
        // Normalized coin Y amount [1e18]
        uint128 y;
        // Liquidity = p(i) * X[i] + Y[i]
        uint256 l;
    }

    // X
    IERC20 public immutable coin0;
    // Y
    IERC20 public immutable coin1;

    // 10^(18 - token X decimals)
    uint128 public immutable norm0;
    // 10^(18 - token X decimals)
    uint128 public immutable norm1;

    // 0.3%
    uint128 public constant FEE = 0.003 * 1e5;

    int24 public tick;
    mapping(int24 => Bucket) public buckets;
    // Tick => user => liquidity
    mapping(int24 => mapping(address => uint256)) public liqs;

    constructor(address c0, address c1, int24 t) {
        coin0 = IERC20(c0);
        coin1 = IERC20(c1);

        uint8 dec0 = coin0.decimals();
        require(dec0 <= 18, "coin0 decimals > 18");
        uint8 dec1 = coin1.decimals();
        require(dec1 <= 18, "coin1 decimals > 18");
        norm0 = u128(10 ** (18 - dec0));
        norm1 = u128(10 ** (18 - dec1));

        tick = t;
    }

    function inc(int24 i, uint128 c0, uint128 c1, address dst)
        external
        returns (uint128, uint128, uint256)
    {
        int24 t = tick;

        if (i < t) {
            c0 = 0;
        }
        if (t < i) {
            c1 = 0;
        }

        uint128 x = c0 * norm0;
        uint128 y = c1 * norm1;
        // TODO: calc price at t
        // uint128 p = pow(B, t);
        uint128 p = 0;
        uint256 dl = mul(p, x) / RAY_256 + uint256(y);

        Bucket storage buck = buckets[t];
        buck.x += x;
        buck.y += y;
        buck.l += dl;

        liqs[t][dst] += dl;

        if (c0 > 0) {
            coin0.safeTransferFrom(msg.sender, address(this), c0);
        }
        if (c1 > 0) {
            coin1.safeTransferFrom(msg.sender, address(this), c1);
        }

        return (c0, c1, dl);
    }

    function dec(uint256 t, uint128 dx, uint128 dy) external {}
    function swap() external {}
}
