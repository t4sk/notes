// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";

// Sorted doubly linked list
contract List {
    struct Node {
        uint256 prev;
        uint256 next;
        uint256 val;
    }

    // id
    uint256 i;
    // start
    uint256 s;
    // end
    uint256 e;
    mapping(uint256 => Node) nodes;

    function insert(uint256 p, uint256 val) public {
        i += 1;
        require(p < i);

        // Not initialized
        require(nodes[i].prev == 0);
        require(nodes[i].next == 0);

        Node storage prev = nodes[p];
        uint256 n = prev.next;
        Node storage next = nodes[n];

        // TODO: fix code to handle uninitialized prev or next
        prev.next = i;
        next.prev = i;

        require(val >= prev.val);
        require(val <= next.val);

        nodes[i] = Node({
            prev: p,
            next: n,
            val: val
        });

        // TODO: update s and e
    }

    function remove(uint256 i) public {
        Node memory curr = nodes[i];
        Node storage prev = nodes[curr.prev];
        Node storage next = nodes[curr.next];
        // prev <-> cur <-> next
        prev.next = curr.next;
        next.prev = curr.prev;
    }

    function find(uint256 val) public {}

    function list() public {}
}

contract ListTest is Test {
}
