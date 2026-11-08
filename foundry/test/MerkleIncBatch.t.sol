// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MerkleTree} from "../src/MerkleIncBatch.sol";

library Spec {
    bytes32 internal constant Z = keccak256("zero");

    function hash(bytes32 a, bytes32 b) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a, b));
    }

    function zero(uint256 lvl) internal pure returns (bytes32 z) {
        z = Z;
        for (uint256 i = 0; i < lvl; ++i) {
            z = hash(z, z);
        }
    }

    function node(bytes32[] memory vals, uint256 lvl, uint256 idx)
        internal
        pure
        returns (bytes32)
    {
        // A node at level lvl with index idx covers the leaves
        // starting at idx * 2^lvl = idx << lvl
        if ((idx << lvl) >= vals.length) {
            return zero(lvl);
        }
        if (lvl == 0) {
            return vals[idx];
        }
        return
            hash(node(vals, lvl - 1, 2 * idx), node(vals, lvl - 1, 2 * idx + 1));
    }

    function root(bytes32[] memory vals, uint256 depth)
        internal
        pure
        returns (bytes32)
    {
        return node(vals, depth, 0);
    }
}

contract IncMerkleTest is Test {
    MerkleTree internal tree;

    function setUp() public {
        tree = new MerkleTree();
    }

    function make(uint256 seed, uint256 len)
        internal
        pure
        returns (bytes32[] memory vals)
    {
        vals = new bytes32[](len);
        for (uint256 i = 0; i < len; ++i) {
            vals[i] = keccak256(abi.encode(seed, i));
        }
    }

    function test_zeros() public view {
        for (uint256 i = 0; i < tree.DEPTH(); i++) {
            assertEq(tree.zeros(i), Spec.zero(i));
        }
        assertEq(tree.root(), Spec.zero(tree.DEPTH()));
    }

    function test_empty_root() public view {
        assertEq(tree.root(), Spec.root(new bytes32[](0), tree.DEPTH()));
        assertEq(tree.root(), tree.zoot());
    }

    function test_zero_count_is_noop() public {
        bytes32 root = tree.root();
        tree.insert(new bytes32[](0));
        assertEq(tree.root(), root);
        assertEq(tree.next(), 0);
    }

    function test_overflow_starts_new_tree() public {
        tree.insert(make(1, tree.CAP() - 1));
        assertEq(tree.num(), 0);
        bytes32 root = tree.root();

        bytes32[] memory vals = make(2, 2);
        tree.insert(vals);
        assertEq(tree.num(), 1);
        assertEq(tree.next(), 2);
        assertEq(tree.root(), Spec.root(vals, tree.DEPTH()));
        assertTrue(tree.hist(0, root));
        assertTrue(tree.hist(1, tree.root()));
    }

    function test_fill_exactly_then_overflow() public {
        uint256 cap = tree.CAP();
        bytes32[] memory full = make(3, cap);
        tree.insert(full);
        assertEq(tree.num(), 0);
        assertEq(tree.next(), cap);
        assertEq(tree.root(), Spec.root(full, tree.DEPTH()));

        bytes32[] memory vals = make(4, 1);
        tree.insert(vals);
        assertEq(tree.num(), 1);
        assertEq(tree.next(), 1);
        assertEq(tree.root(), Spec.root(vals, tree.DEPTH()));
    }

    function test_one_by_one() public {
        uint256 cap = tree.CAP();
        bytes32[] memory leaves = new bytes32[](cap);
        for (uint256 i = 0; i < cap; i++) {
            bytes32[] memory vals = make(100 + i, 1);
            tree.insert(vals);
            leaves[i] = vals[0];

            bytes32[] memory copy = new bytes32[](i + 1);
            for (uint256 k = 0; k <= i; k++) {
                copy[k] = leaves[k];
            }
            assertEq(tree.root(), Spec.root(copy, tree.DEPTH()));
        }
    }

    function test_fuzz_two_batches(uint256 a, uint256 b, uint256 seed) public {
        uint256 cap = tree.CAP();
        a = bound(a, 1, cap);
        if (a == cap) {
            return;
        }
        b = bound(b, 1, cap - a);

        bytes32[] memory x = make(seed, a);
        bytes32[] memory y = make(seed ^ uint256(1), b);
        tree.insert(x);
        tree.insert(y);

        bytes32[] memory all = new bytes32[](a + b);
        for (uint256 i = 0; i < a; ++i) {
            all[i] = x[i];
        }
        for (uint256 i = 0; i < b; ++i) {
            all[a + i] = y[i];
        }
        assertEq(tree.root(), Spec.root(all, tree.DEPTH()));
    }
}

contract Handler is Test {
    MerkleTree public immutable tree;
    uint256 public immutable depth;
    uint256 public immutable cap;
    bytes32[] public vals;
    // Tree number
    uint256 public num;

    struct Snap {
        bytes32 root;
        // Tree num
        uint256 num;
    }

    Snap[] public snaps;

    constructor(MerkleTree t) {
        tree = t;
        depth = tree.DEPTH();
        cap = tree.CAP();
        snaps.push(Snap({root: Spec.root(vals, depth), num: 0}));
    }

    function insert(uint256 seed, uint256 n) external {
        n = bound(n, 0, cap);

        bytes32[] memory hs = new bytes32[](n);
        for (uint256 i = 0; i < n; i++) {
            hs[i] = keccak256(abi.encode(seed, i));
        }

        if (n > 0) {
            if (vals.length + n > cap) {
                delete vals;
                num += 1;
            }
            for (uint256 i = 0; i < n; i++) {
                vals.push(hs[i]);
            }
        }

        tree.insert(hs);

        if (n > 0) {
            snaps.push(Snap({root: Spec.root(vals, depth), num: num}));
        }
    }

    function get() public view returns (bytes32[] memory) {
        return vals;
    }

    function len() public view returns (uint256) {
        return vals.length;
    }

    function count() public view returns (uint256) {
        return snaps.length;
    }
}

contract IncMerkleInv is Test {
    MerkleTree internal tree;
    Handler internal handler;

    function setUp() public {
        tree = new MerkleTree();
        handler = new Handler(tree);

        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = Handler.insert.selector;
        targetSelector(
            FuzzSelector({addr: address(handler), selectors: selectors})
        );
    }

    function invariant_zeros() public view {
        for (uint256 i = 0; i < tree.DEPTH(); ++i) {
            assertEq(tree.zeros(i), Spec.zero(i), "zeros");
        }
    }

    function invariant_root() public view {
        assertEq(tree.root(), Spec.root(handler.get(), tree.DEPTH()));
    }

    function invariant_root_history() public view {
        assertTrue(tree.hist(tree.num(), tree.root()), "hist");
        uint256 cnt = handler.count();
        for (uint256 i = 0; i < cnt; ++i) {
            (bytes32 r, uint256 t) = handler.snaps(i);
            assertTrue(tree.hist(t, r), "snapshot");
        }
    }

    function invariant_tree() public view {
        assertEq(tree.num(), handler.num());
    }

    function invariant_next() public view {
        assertLe(tree.next(), tree.CAP());
        assertEq(tree.next(), handler.len());
    }

    // Whenever next >> i is odd,
    // nodes[i] is the hash of the complete subtree at level i
    // index (next >> i) - 1
    function invariant_nodes() public view {
        bytes32[] memory vals = handler.get();
        uint256 n = tree.next();
        for (uint256 i = 0; i < tree.DEPTH(); i++) {
            // Check odd
            if (((n >> i) & 1) == 1) {
                assertEq(
                    tree.nodes(i), Spec.node(vals, i, (n >> i) - 1), "nodes"
                );
            }
        }
    }
}
