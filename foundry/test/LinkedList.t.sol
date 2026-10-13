// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

// Sorted doubly linked list
contract List {
    // Pointers and length
    struct P {
        // id
        uint64 i;
        // start
        uint64 s;
        // end
        uint64 e;
        // length
        uint64 len;
    }

    struct Node {
        bool init;
        // 0 = no prev node
        uint64 prev;
        // 0 = no next node
        uint64 next;
        uint256 val;
    }

    P public p;
    mapping(uint256 => Node) public nodes;

    function get(uint256 i) public view returns (Node memory) {
        return nodes[i];
    }

    // Set pi = 0 to insert in front of s
    function insert(uint64 pi, uint256 val) public returns (uint256) {
        P memory m = p;
        m.i += 1;
        require(pi < m.i, "pi >= i");

        // Not initialized
        Node storage node = nodes[m.i];
        // assert(!node.init);
        // assert(node.prev == 0);
        // assert(node.next == 0);
        // assert(node.val == 0);

        if (pi == 0) {
            Node storage next = nodes[m.s];

            if (next.init) {
                // assert(next.prev == 0);
                require(val <= next.val, "val > next");
                next.prev = m.i;
            } else {
                // assert(m.s == 0);
                // assert(m.e == 0);
                // assert(next.prev == 0);
                // assert(next.next == 0);
                // assert(next.val == 0);
            }

            node.init = true;
            // node.prev = 0;
            node.next = m.s;
            node.val = val;

            m.s = m.i;
            if (node.next == 0) {
                m.e = m.i;
            }
        } else {
            Node storage prev = nodes[pi];
            // User input (removed node), so revert instead of panic
            require(prev.init, "!init");

            uint64 ni = prev.next;
            Node storage next = nodes[ni];

            require(val >= prev.val, "val < prev");
            prev.next = m.i;

            if (next.init) {
                // assert(next.prev == pi);
                require(val <= next.val, "val > next");
                next.prev = m.i;
            } else {
                // assert(next.prev == 0);
                // assert(next.next == 0);
                // assert(next.val == 0);
                // assert(pi == m.e);
            }

            node.init = true;
            node.prev = uint64(pi); // safe: 0 < pi < m.i <= max uint64
            node.next = ni;
            node.val = val;

            if (!next.init) {
                m.e = m.i;
            }
        }

        m.len += 1;
        p = m;

        return m.i;
    }

    function remove(uint64 i) public {
        P memory m = p;
        Node memory curr = nodes[i];

        require(curr.init, "!init");

        if (curr.prev != 0) {
            nodes[curr.prev].next = curr.next;
        } else {
            m.s = curr.next;
        }
        if (curr.next != 0) {
            nodes[curr.next].prev = curr.prev;
        } else {
            m.e = curr.prev;
        }

        delete nodes[i];

        m.len -= 1;
        p = m;
    }

    // Last node with val < target, or 0
    function find(uint256 val) public view returns (uint64 pi) {
        uint64 c = p.s;
        while (c != 0 && nodes[c].val < val) {
            pi = c;
            c = nodes[c].next;
        }
    }

    function arr() public view returns (uint256[] memory vals) {
        P memory m = p;
        vals = new uint256[](m.len);
        uint256 c = m.s;
        uint256 i = 0;
        while (c != 0) {
            Node memory node = nodes[c];
            vals[i] = node.val;
            i++;
            c = node.next;
        }
    }
}

library Array {
    function insert(uint256[] storage arr, uint256 i, uint256 val) internal {
        require(i <= arr.length);
        // Shift left to right
        arr.push(0);
        for (uint256 j = arr.length - 1; j > i; j--) {
            arr[j] = arr[j - 1];
        }
        arr[i] = val;
    }

    function remove(uint256[] storage arr, uint256 i) internal {
        require(i < arr.length);
        // Copy right to left, remove last
        for (uint256 j = i; j < arr.length - 1; j++) {
            arr[j] = arr[j + 1];
        }
        arr.pop();
    }
}

contract Handler is Test {
    using Array for uint256[];

    List public list;

    uint256[] public ids;
    uint256[] public vals;

    constructor(address l) {
        list = List(l);
    }

    function length() external view returns (uint256) {
        return ids.length;
    }

    function insert(uint256 val) public {
        val = bound(val, 0, 16);

        // Insert before the first element >= val, mirroring find()
        uint256 idx;
        while (idx < vals.length && vals[idx] < val) {
            idx++;
        }

        uint256 id = list.insert(list.find(val), val);

        ids.insert(idx, id);
        vals.insert(idx, val);
    }

    function remove(uint256 seed) public {
        if (ids.length == 0) {
            return;
        }

        uint256 idx = bound(seed, 0, ids.length - 1);

        list.remove(uint64(ids[idx]));

        ids.remove(idx);
        vals.remove(idx);
    }
}

contract LinkedListTest is Test {
    List list;

    function setUp() public {
        list = new List();
    }

    function check(uint256 s, uint256 e, uint256 len) internal view {
        (, uint64 ps, uint64 pe, uint64 pl) = list.p();
        assertEq(uint256(ps), s);
        assertEq(uint256(pe), e);
        assertEq(uint256(pl), len);
    }

    function checkNode(uint256 id, uint256 prev, uint256 next, uint256 val)
        internal
        view
    {
        List.Node memory n = list.get(id);
        assertTrue(n.init);
        assertEq(uint256(n.prev), prev);
        assertEq(uint256(n.next), next);
        assertEq(n.val, val);
    }

    function test() public {
        // Insert
        list.insert(0, 3);
        check(1, 1, 1);
        checkNode(1, 0, 0, 3);

        list.insert(0, 2);
        check(2, 1, 2);
        checkNode(2, 0, 1, 2);
        checkNode(1, 2, 0, 3);

        list.insert(0, 1);
        check(3, 1, 3);
        // order: 3 (val 1) <-> 2 (val 2) <-> 1 (val 3)
        checkNode(3, 0, 2, 1);
        checkNode(2, 3, 1, 2);
        checkNode(1, 2, 0, 3);

        uint256[] memory arr = list.arr();
        assertEq(arr.length, 3);
        assertEq(arr[0], 1);
        assertEq(arr[1], 2);
        assertEq(arr[2], 3);

        // Remove middle
        list.remove(2);
        check(3, 1, 2);
        checkNode(3, 0, 1, 1);
        checkNode(1, 3, 0, 3);
        assertFalse(list.get(2).init);

        arr = list.arr();
        assertEq(arr.length, 2);
        assertEq(arr[0], 1);
        assertEq(arr[1], 3);

        // Remove head
        list.remove(3);
        check(1, 1, 1);
        checkNode(1, 0, 0, 3);
        assertFalse(list.get(3).init);

        arr = list.arr();
        assertEq(arr.length, 1);
        assertEq(arr[0], 3);

        // Remove last
        list.remove(1);
        check(0, 0, 0);
        assertFalse(list.get(1).init);

        arr = list.arr();
        assertEq(arr.length, 0);
    }
}

contract LinkedListInvTest is Test {
    List list;
    Handler h;

    function setUp() public {
        list = new List();
        h = new Handler(address(list));
        targetContract(address(h));
    }

    function invariant_cursors() public view {
        (, uint64 s, uint64 e, uint64 len) = list.p();
        if (len == 0) {
            assertEq(uint256(s), 0);
            assertEq(uint256(e), 0);
        }
    }

    function invariant_eq() public view {
        (, uint64 s, uint64 e, uint64 len) = list.p();

        uint256 n = h.length();
        assertEq(uint256(len), n);

        uint256 curr = s;
        uint256 prev;
        for (uint256 k = 0; k < n; k++) {
            assertEq(curr, h.ids(k));
            (bool init, uint64 pp, uint64 nn, uint256 v) = list.nodes(curr);
            uint256 pr = pp;
            uint256 nx = nn;
            assertTrue(init);
            assertEq(pr, prev);
            assertEq(v, h.vals(k));

            if (pr != 0) {
                (,,, uint256 pv) = list.nodes(pr);
                assertLe(pv, v);
            }
            if (nx != 0) {
                (,,, uint256 nv) = list.nodes(nx);
                assertLe(v, nv);
            }

            prev = curr;
            curr = nx;
        }
        assertEq(curr, 0);
        assertEq(uint256(e), prev);
    }
}
