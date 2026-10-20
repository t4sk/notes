// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";

contract ECOpts is Test {
    // BN254 curve prime
    uint256 private constant P =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1 {
        uint256 x;
        uint256 y;
    }

    // y^2 = x^3 + 3 / (9 + i)
    // x = [imaginary, real]
    // y = [imaginary, real]
    struct G2 {
        uint256[2] x;
        uint256[2] y;
    }

    function add(G1 memory p, G1 memory q) internal view returns (G1 memory r) {
        // Call fails if x or y >= P
        // Call fails if point is not on the curve
        // y^2 = (x^3 + 3) % P
        uint256[4] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = q.x;
        input[3] = q.y;

        bool ok;
        assembly {
            ok := staticcall(
                gas(),
                // EC add
                6,
                input,
                // input length = 128 bytes
                0x80,
                r,
                0x40
            )
        }
        require(ok, "add failed");
    }

    function mul(G1 memory p, uint256 s) internal view returns (G1 memory r) {
        uint256[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;

        bool ok;
        assembly {
            ok := staticcall(
                gas(),
                // EC scalar mul
                7,
                input,
                // input length = 128 bytes
                0x80,
                r,
                0x40
            )
        }
        require(ok, "mul failed");
    }

    function pair(G1 memory a, G2 memory b, G1 memory c, G2 memory d)
        internal
        view
        returns (uint256)
    {
        uint256[12] memory input = [
            a.x,
            a.y,
            b.x[0],
            b.x[1],
            b.y[0],
            b.y[1],
            c.x,
            c.y,
            d.x[0],
            d.x[1],
            d.y[0],
            d.y[1]
        ];

        uint256[1] memory out;
        bool ok;
        assembly {
            ok := staticcall(
                gas(),
                // EC pairing address
                8,
                input,
                // Calldata size in bytes (12 * 32)
                mul(12, 32),
                // Writes 32 bytes to 0th element in out
                out,
                0x20
            )
        }
        require(ok, "pair failed");

        // Returns 1 if e(a, b) * e(c, d) = 1
        //         0 otherwise
        return out[0];
    }

    function test_ec_add() public view {
        // y^2 = (x^3 + 3) % P or x, y = 0, 0
        G1 memory p = G1({x: 1, y: 2});
        G1 memory q = G1({x: 1, y: 2});
        G1 memory r = add(p, q);

        console.log("r.x", r.x);
        console.log("r.y", r.y);
    }

    function test_ec_mul() public view {
        // y^2 = (x^3 + 3) % P or x, y = 0, 0
        G1 memory p = G1({x: 1, y: 2});
        uint256 s = 2;
        G1 memory r = mul(p, s);

        console.log("r.x", r.x);
        console.log("r.y", r.y);
    }

    function test_ec_pair() public view {
        G1 memory a = G1({x: 1, y: 2});
        // Standard G2 generator
        G2 memory b = G2({
            x: [
                uint256(
                    11559732032986387107991004021392285783925812861821192530917403151452391805634
                ),
                uint256(
                    10857046999023057135944570762232829481370756359578518086990519993285655852781
                )
            ],
            y: [
                uint256(
                    4082367875863433681332203403145435568316851327593401208105741076214120093531
                ),
                uint256(
                    8495653923123431417604973247489272438418190587263600148770280649306958101930
                )
            ]
        });
        G1 memory c = G1({x: 1, y: 2});
        G2 memory d = G2({x: [b.x[0], b.x[1]], y: [P - b.y[0], P - b.y[1]]});

        // e(a, b) * e(c, d) = 1 iff e(a, b) = e(c, d)^(-1)
        // e(a, b) * e(a, -b) = 1
        uint256 r = pair(a, b, c, d);
        console.log("r", r);
    }
}
