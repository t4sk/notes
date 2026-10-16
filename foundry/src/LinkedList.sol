// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

// Sorted doubly linked list
contract List {
    // Pointers and length
    struct Pointer {
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

    Pointer public ptr;
    mapping(uint256 => Node) public nodes;

    function get(uint256 i) public view returns (Node memory) {
        return nodes[i];
    }

    // Insert to the right of p
    // Set p = 0 to insert to the left of s
    function insert(uint64 p, uint256 val) public returns (uint256) {
        Pointer memory m = ptr;
        // Previous id must already exist
        require(p <= m.i, "p > i");

        m.i += 1;
        Node storage node = nodes[m.i];

        if (p == 0) {
            Node storage next = nodes[m.s];

            if (next.init) {
                require(val <= next.val, "val > next");
                next.prev = m.i;
            }

            node.init = true;
            node.next = m.s;
            node.val = val;

            m.s = m.i;
            if (!next.init) {
                m.e = m.i;
            }
        } else {
            Node storage prev = nodes[p];
            require(prev.init, "!init");

            uint64 n = prev.next;
            Node storage next = nodes[n];

            require(prev.val <= val, "val < prev");
            prev.next = m.i;

            if (next.init) {
                require(val <= next.val, "val > next");
                next.prev = m.i;
            }

            node.init = true;
            node.prev = p;
            node.next = n;
            node.val = val;

            if (!next.init) {
                m.e = m.i;
            }
        }

        m.len += 1;
        ptr = m;

        return m.i;
    }

    function remove(uint64 i) public {
        Pointer memory m = ptr;
        Node memory node = nodes[i];
        require(node.init, "!init");

        if (node.prev != 0) {
            nodes[node.prev].next = node.next;
        } else {
            // node.prev = 0 -> i = s
            m.s = node.next;
        }

        if (node.next != 0) {
            nodes[node.next].prev = node.prev;
        } else {
            // node.next = 0 -> i = e
            m.e = node.prev;
        }

        delete nodes[i];

        m.len -= 1;
        ptr = m;
    }

    // Last node with val < target, not found = 0
    function find(uint256 val) public view returns (uint64 p) {
        uint64 c = ptr.s;
        while (c != 0 && nodes[c].val < val) {
            p = c;
            c = nodes[c].next;
        }
    }

    function vals() public view returns (uint256[] memory vs) {
        Pointer memory m = ptr;
        vs = new uint256[](m.len);
        uint256 c = m.s;
        uint256 i = 0;
        while (c != 0) {
            Node memory node = nodes[c];
            vs[i] = node.val;
            i++;
            c = node.next;
        }
    }
}

