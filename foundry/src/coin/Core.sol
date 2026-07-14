// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Auth} from "./lib/Auth.sol";
import {V, W, mul, muldiv} from "./lib/Math.sol";

// TODO: ROCQ
// TODO: unify lending + stablecoin
contract Core is Auth {
    // Collateral parameters
    struct Col {
        // Total normalized debt [V]
        uint128 tot;
        // Product of rates [V]
        uint128 rate;
        // Price of collateral [V]
        uint128 spot;
        // Max total debt [W]
        uint256 max;
        // Min debt of a position [W]
        uint256 min;
    }

    // Collateralized debt position
    struct Pos {
        // [V]
        uint128 col;
        // Normalized coin debt [V]
        uint128 debt;
    }

    // [V]
    mapping(bytes32 gem => mapping(address usr => uint128 amt)) public gem;
    // [W]
    mapping(bytes32 coin => mapping(address usr => uint256 amt)) public coin;
    // [W]
    mapping(bytes32 coin => uint256) public sum;
    mapping(bytes32 key => Col) public cols;
    mapping(bytes32 key => mapping(address usr => Pos)) public positions;

    function key(bytes32 coin, bytes32 gem) public pure returns (bytes32 k) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, coin)
            mstore(add(ptr, 0x20), gem)
            k := keccak256(ptr, 0x40)
        }
    }

    function join(bytes32 g, address dst, uint128 amt) external auth {
        gem[g][dst] += amt;
    }

    function exit(bytes32 g, uint128 amt) external {
        gem[g][msg.sender] -= amt;
    }

    function move(bytes32 g, address dst, uint128 amt) external {
        gem[g][msg.sender] -= amt;
        gem[g][dst] += amt;
    }

    function mint(bytes32 c, address dst, uint256 amt) external auth {
        coin[c][dst] += amt;
        sum[c] += amt;
        // TODO: store unbacked total?
    }

    function burn(bytes32 c, uint256 amt) external {
        coin[c][msg.sender] -= amt;
        sum[c] -= amt;
    }

    function transfer(bytes32 c, address dst, uint256 amt) external {
        coin[c][msg.sender] -= amt;
        coin[c][dst] += amt;
    }

    function inc(bytes32 c, bytes32 g, uint128 debt, uint128 gmt)
        external
        returns (uint256)
    {
        // TODO: require live
        bytes32 k = key(c, g);

        Col memory col = cols[k];
        Pos memory pos = positions[k][msg.sender];
        require(col.rate != 0, "col not init");

        pos.debt += debt;
        pos.col += gmt;
        col.tot += debt;

        uint256 amt = mul(debt, col.rate);
        uint256 d = mul(pos.debt, col.rate);

        require(d >= col.min, "debt < min");
        // Increase collateral or over collateralized
        require(debt == 0 || d < mul(pos.col, col.spot), "under collateralized");
        // TODO: global max?
        require(mul(col.tot, col.rate) <= col.max, "tot > max");

        gem[g][msg.sender] -= gmt;
        coin[c][msg.sender] += amt;
        sum[c] += amt;

        cols[k].tot = col.tot;
        positions[k][msg.sender] = pos;

        return amt;
    }

    function dec(bytes32 c, bytes32 g, uint128 debt, uint128 gmt)
        external
        returns (uint256)
    {
        // TODO: require live
        bytes32 k = key(c, g);

        Col memory col = cols[k];
        Pos memory pos = positions[k][msg.sender];
        require(col.rate != 0, "col not init");

        pos.debt -= debt;
        pos.col -= gmt;
        col.tot -= debt;

        uint256 amt = mul(debt, col.rate);
        uint256 d = mul(pos.debt, col.rate);

        require(d == 0 || d >= col.min, "debt < min");
        // Decrease debt or over collateralized
        require(gmt == 0 || d < mul(pos.col, col.spot), "under collateralized");

        gem[g][msg.sender] += gmt;
        coin[c][msg.sender] -= amt;
        sum[c] -= amt;

        cols[k].tot = col.tot;
        positions[k][msg.sender] = pos;

        return amt;
    }

    function grab() external auth {}

    function sync(bytes32 c, bytes32 g, uint128 dr) public auth {
        bytes32 k = key(c, g);
        cols[k].rate = muldiv(cols[k].rate, dr, W);
        // cols[k].last = block.timestamp;
    }
}
