// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

// Sorted doubly linked list
contract List {
    // TODO: use uint64
    struct Node {
        bool init;
        // 0 = no prev node
        uint256 prev;
        // 0 = no next node
        uint256 next;
        uint256 val;
    }

    // TODO: use u64
    // Invariant: s <= i <= e
    // id
    uint256 public i;
    // start
    uint256 public s;
    // end
    uint256 public e;
    uint256 public len;
    mapping(uint256 => Node) public nodes;

    // Set p = 0 to insert in front of s
    function insert(uint256 p, uint256 val) public returns (uint256) {
        i += 1;
        require(p < i, "p >= i");

        // Not initialized
        Node storage node = nodes[i];
        assert(!node.init);
        assert(node.prev == 0);
        assert(node.next == 0);
        assert(node.val == 0);

        if (p == 0) {
            Node storage next = nodes[s];

            if (next.init) {
                assert(next.prev == 0);
                require(val <= next.val);
                next.prev = i;
            } else {
                assert(s == 0);
                assert(e == 0);
                assert(next.prev == 0);
                assert(next.next == 0);
                assert(next.val == 0);
            }

            node.init = true;
            // node.prev = 0;
            node.next = s;
            node.val = val;

            s = i;
            if (node.next == 0) {
                e = i;
            }
        } else {
            Node storage prev = nodes[p];
            assert(prev.init);

            uint256 n = prev.next;
            Node storage next = nodes[n];

            require(val >= prev.val);
            prev.next = i;

            if (next.init) {
                assert(next.prev > 0);
                assert(next.prev == prev.next);
                require(val <= next.val);
                next.prev = i;
            } else {
                assert(next.prev == 0);
                assert(next.next == 0);
                assert(next.val == 0);
                assert(p == e);
            }

            node.init = true;
            node.prev = p;
            node.next = n;
            node.val = val;

            if (!next.init) {
                e = i;
            }
        }

        len += 1;

        return i;
    }

    function remove(uint256 i) public {
        Node memory curr = nodes[i];

        // Initialized
        require(curr.prev != 0 || curr.next != 0);

        Node storage prev = nodes[curr.prev];
        Node storage next = nodes[curr.next];
        // prev <-> cur <-> next
        prev.next = curr.next;
        next.prev = curr.prev;

        if (curr.prev == 0) {
            s = curr.next;
        }
        if (curr.next == 0) {
            e = curr.prev;
        }

        delete nodes[i];

        len -= 1;
    }

    function find(uint256 val) public view returns (uint256 p) {
        p = s;
        Node memory node = nodes[p];

        if (!node.init) {
            return 0;
        }

        // val <= node.val -> s

        while (node.val < val) {
            uint256 n = node.next;
            node = nodes[n];
            if (!node.init) {
                return p;
            }
            p = n;
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

contract Handler {
    List list;

    // TODO: array
    uint256[] arr;

    constructor(address l) {
        list = List(l);
    }

    function insert(uint256 val) public {
        uint256 p = list.find(val);
        list.insert(p, val);
    }

    function remove(uint256 i) public {
        list.remove(i);
    }
}

contract LinkedListTest is Test {
    List list;
    Handler h;

    function setUp() public {
        list = new List();
        h = new Handler(address(list));
    }

    function invariant() public view {
        // TODO
    }
}
