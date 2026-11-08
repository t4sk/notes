// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// Incremental Merkle tree with batch insert
contract MerkleTree {
    // Zero hash
    bytes32 public constant Z = keccak256("zero");

    uint256 public constant DEPTH = 4;
    uint256 public constant CAP = 2 ** DEPTH;

    // Next leaf index = current leaf count
    uint256 public next;
    // Tree number, increments when batch insert doesn't fit inside leaf level
    uint256 public num;
    bytes32 public root;
    // Merkle root of all zeros
    bytes32 public immutable zoot;

    // Zero hash at each level
    bytes32[DEPTH] public zeros;
    // Right-most left hash at each level
    bytes32[DEPTH] public nodes;
    // tree number => root => exists
    mapping(uint256 => mapping(bytes32 => bool)) public hist;

    constructor() {
        bytes32 z = Z;
        for (uint256 i; i < DEPTH; ++i) {
            zeros[i] = z;
            nodes[i] = z;
            z = hash(z, z);
        }

        root = z;
        zoot = z;
        hist[0][z] = true;
    }

    function hash(bytes32 x, bytes32 y) private pure returns (bytes32 z) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, x)
            mstore(add(ptr, 0x20), y)
            z := keccak256(ptr, 0x40)
        }
    }

    // Initialize new tree
    function bump() internal {
        root = zoot;
        next = 0;
        num += 1;
    }

    function insert(bytes32[] memory vals) public {
        uint256 count = vals.length;
        if (count == 0) {
            return;
        }

        // Create new tree if current count + insert count > capacity
        if (next + count > 2 ** DEPTH) {
            bump();
        }

        // Starting index at each level (updated at each level)
        uint256 s = next;
        next += count;

        // Next level hash index
        uint256 h;
        // Next level start index (parent)
        uint256 p;

        for (uint256 level = 0; level < DEPTH; level++) {
            p = s >> 1;
            // Current level insertion index
            uint256 i;

            // Align starting index to left branch
            if (s % 2 == 1) {
                // h always = 0
                h = (s >> 1) - p;
                assert(h == 0);

                // nodes[level] = right-most left node
                // hs[h] = hash for next level
                vals[h] = hash(nodes[level], vals[i]);
                i += 1;
                s += 1;
            }

            while (i < count) {
                // count is even -> last i = count - 2 -> left = hs[i], right = hs[i + 1]
                // count is odd  -> last i = count - 1 -> left = hs[i], right = zero
                bytes32 r = i < count - 1 ? vals[i + 1] : zeros[level];

                // count is even -> last i = count - 2 (hs[i] = left branch)
                //          odd  -> last i = count - 1 (hs[i] = left branch)
                if (i == count - 1 || i == count - 2) {
                    // nodes[level] = right most left branch
                    nodes[level] = vals[i];
                }

                // Calculate next level index of hs = s // 2 - next level start index
                h = (s >> 1) - p;
                vals[h] = hash(vals[i], r);

                s += 2;
                i += 2;
            }

            // Update starting index for next level
            s = p;
            // Count for next level = last hash index for next level + 1
            count = h + 1;
        }

        root = vals[0];
        hist[num][root] = true;
    }
}
