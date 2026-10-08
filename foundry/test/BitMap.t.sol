// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

// 2**8 = 256
// 1e18 < 2**64
// 1e9 < 2**32

contract BitMap {
    // [15 to 8] -> [7 to 0]
    mapping(uint256 => uint256) public b0;
    // [23 to 16] -> [15 to 8]
    mapping(uint256 => uint256) public b1;
    // [31 to 24] -> [23 to 16]
    mapping(uint256 => uint256) public b2;
    // [39 to 32] -> [31 to 24]
    mapping(uint256 => uint256) public b3;
    // [47 to 40] -> [39 to 32]
    mapping(uint256 => uint256) public b4;
    // [55 to 48] -> [47 to 40]
    mapping(uint256 => uint256) public b5;
    // [63 to 56] -> [55 to 48]
    mapping(uint256 => uint256) public b6;

    function insert(uint64 x) public {
        // 64 bits
        // x = [ x7 ][ x6 ][ x5 ][ x4 ][ x3 ][ x2 ][ x1 ][ x0 ]
        //       8     8     8     8     8     8     8     8
        uint8 x0 = uint8(x >> 0);
        uint8 x1 = uint8(x >> 8);
        uint8 x2 = uint8(x >> 16);
        uint8 x3 = uint8(x >> 24);
        uint8 x4 = uint8(x >> 32);
        uint8 x5 = uint8(x >> 40);
        uint8 x6 = uint8(x >> 48);
        uint8 x7 = uint8(x >> 56);

        b0[x1] |= uint256(1) << x0;
        b1[x2] |= uint256(1) << x1;
        b2[x3] |= uint256(1) << x2;
        b3[x4] |= uint256(1) << x3;
        b4[x5] |= uint256(1) << x4;
        b5[x6] |= uint256(1) << x5;
        b6[x7] |= uint256(1) << x6;
    }
}

contract BitMap2 {
    // 64 bits
    //       32     8     8     8     8
    // x = [ x0 ][ x1 ][ x2 ][ x3 ][ x4 ]
    // x0 => x1
    mapping(uint32 => uint256) b0;
    // x1 => x2
    mapping(uint8 => uint256) b1;
    // x2 => x3
    mapping(uint8 => uint256) b2;
    // x3 => x4
    mapping(uint8 => uint256) b3;

    function insert(uint64 x) public {
        // [63...32]
        uint32 x0 = uint32(x >> 32);
        // [31...24]
        uint8 x1 = uint8(x >> 24);
        // [23...16]
        uint8 x2 = uint8(x >> 16);
        // [15...8]
        uint8 x3 = uint8(x >> 8);
        // [7...0]
        uint8 x4 = uint8(x >> 0);

        b0[x0] |= uint256(1) << x1;
        b1[x1] |= uint256(1) << x2;
        b2[x2] |= uint256(1) << x3;
        b3[x3] |= uint256(1) << x4;
    }
}

contract BitMap3 {
    // 64 bits
    //       32     8    16     8
    // x = [ x0 ][ x1 ][ x2 ][ x3 ]
    // x0 => x1
    mapping(uint32 => uint256) b0;
    // x2 => x3
    mapping(uint16 => uint256) b1;

    function insert(uint64 x) public {
        // [63...32]
        uint32 x0 = uint32(x >> 32);
        // [31...24]
        uint8 x1 = uint8(x >> 24);
        // [23...8]
        uint8 x2 = uint8(x >> 8);
        // [7...0]
        uint8 x3 = uint8(x >> 0);

        b0[x0] |= uint256(1) << x1;
        b1[x2] |= uint256(1) << x3;
    }
}

contract BitMapTest is Test {
    BitMap bitMap;
    BitMap2 bitMap2;
    BitMap3 bitMap3;

    function setUp() public {
        bitMap = new BitMap();
        bitMap2 = new BitMap2();
        bitMap3 = new BitMap3();
    }

    function test() public {
        // 171945 gas
        // bitMap.insert(1);

        // 101181 gas
        // bitMap2.insert(1);

        bitMap3.insert(1);
    }
}
