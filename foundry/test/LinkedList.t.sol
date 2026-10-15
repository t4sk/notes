// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {List} from "../src/LinkedList.sol";

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

    function len() public view returns (uint256) {
        return vals.length;
    }

    function insert(uint256 val) public {
        val = bound(val, 0, 16);

        uint256 i;
        while (i < vals.length && vals[i] < val) {
            i++;
        }

        uint64 pi = list.find(val);
        uint256 id = list.insert(pi, val);

        ids.insert(i, id);
        vals.insert(i, val);
    }

    function remove(uint256 i) public {
        if (ids.length == 0) {
            return;
        }

        i = bound(i, 0, ids.length - 1);

        list.remove(uint64(ids[i]));

        ids.remove(i);
        vals.remove(i);
    }
}

contract LinkedListTest is Test {
    List list;
    Handler h;

    function setUp() public {
        list = new List();
        h = new Handler(address(list));
        targetContract(address(h));
    }

    function invariant_cursors() public view {
        (uint64 i, uint64 s, uint64 e, uint64 len) = list.p();

        List.Node memory start = list.get(s);
        List.Node memory end = list.get(e);

        if (len == 0) {
            assertEq(uint256(s), 0);
            assertEq(uint256(e), 0);
            assertTrue(!start.init);
            assertTrue(!end.init);
        } else if (len == 1) {
            assertGt(s, 0);
            assertGt(e, 0);
            assertEq(s, e);
            assertTrue(start.init);
            assertTrue(end.init);
        } else {
            assertGt(s, 0);
            assertGt(e, 0);
            assertNotEq(s, e);
            assertTrue(start.init);
            assertTrue(end.init);
        }

        // Start - prev = 0
        assertEq(start.prev, 0);

        // End - next = 0
        assertEq(end.next, 0);

        // Next node for insertion is not initialized
        i += 1;
        List.Node memory node = list.get(i);
        assertTrue(!node.init);
        assertEq(node.prev, 0);
        assertEq(node.next, 0);
        assertEq(node.val, 0);
    }

    // TODO: invariant on find

    function invariant_eq() public view {
        (, uint64 s, uint64 e, uint64 len) = list.p();

        uint256 n = h.len();
        assertEq(uint256(len), n);

        // Check vals
        uint256[] memory vals = list.vals();
        assertEq(uint256(len), vals.length);

        for (uint256 i = 0; i < n; i++) {
            assertEq(vals[i], h.vals(i));
        }

        // Check find
        for (uint256 i = 0; i < n; i++) {
            uint256 p = list.find(h.vals(i));
            if (i == 0) {
                assertEq(p, 0);
            } else {
                // assertEq(p, h.ids(i - 1));
            }
        }

        // Check nodes
        uint64 c = s;
        uint64 p;
        for (uint256 i = 0; i < n; i++) {
            List.Node memory node = list.get(c);

            assertTrue(node.init);
            assertEq(node.prev, p);
            assertEq(node.val, h.vals(i));
            assertEq(c, h.ids(i));

            if (node.prev != 0) {
                List.Node memory prev = list.get(node.prev);
                assertLe(prev.val, node.val);
            }
            if (node.next != 0) {
                List.Node memory next = list.get(node.next);
                assertLe(node.val, next.val);
            }

            p = c;
            c = node.next;
        }
        assertEq(c, 0);
        assertEq(e, p);
    }
}
