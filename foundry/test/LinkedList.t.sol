// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

// Sorted doubly linked list
contract List {
    struct Node {
        bool init;
        uint256 prev;
        uint256 next;
        uint256 val;
    }

    // id
    uint256 public i;
    // start
    uint256 public s;
    // end
    uint256 public e;
    uint256 public len;
    mapping(uint256 => Node) public nodes;

    // Set p = 0 to insert in front of s
    function insert(uint256 p, uint256 val) public {
        i += 1;
        require(p < i, "p >= i");

        // Not initialized
        Node storage node = nodes[i];
        require(!node.init, "node already initialized");

        uint256 n;
        if (p == 0) {
            Node storage start = nodes[s];

            if (start.init) {
                n = start.next;
                require(val <= start.val);
            }

            node.init = true;
            node.prev = 0;
            node.next = s;
            node.val = val;
        } else {
            Node storage prev = nodes[p];
            n = prev.next;
            Node storage next = nodes[n];

            prev.next = i;
            next.prev = i;

            require(val >= prev.val);
            require(val <= next.val);

            node.init = true;
            node.prev = p;
            node.next = n;
            node.val = val;
        }

        // TODO: update s and e
        if (p == 0) {
            s = i;
        }
        if (p != 0 && prev.prev == 0) {
            s = p;
        }

        if (n == 0) {
            e = i;
        }
        if (n != 0 && next.next == 0) {
            e = n;
        }

        len += 1;
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

    function find(uint256 val) public {}

    function list() public {}
}

contract ListTest is Test {
}
