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

    function invariant_pointers() public view {
        (uint64 i, uint64 s, uint64 e, uint64 len) = list.ptr();

        List.Node memory start = list.get(s);
        List.Node memory end = list.get(e);

        if (len == 0) {
            assertEq(uint256(s), 0, "s != 0");
            assertEq(uint256(e), 0, "e != 0");
            assertTrue(!start.init, "start init");
            assertTrue(!end.init, "end init");
        } else if (len == 1) {
            assertGt(s, 0, "s = 0");
            assertGt(e, 0, "e = 0");
            assertEq(s, e, "s != e");
            assertTrue(start.init, "start not init");
            assertTrue(end.init, "end not init");
        } else {
            assertGt(s, 0, "s = 0");
            assertGt(e, 0, "e = 0");
            assertNotEq(s, e, "s = e");
            assertTrue(start.init, "start not init");
            assertTrue(end.init, "end not init");
        }

        // Start - prev = 0
        assertEq(start.prev, 0, "start.prev != 0");

        // End - next = 0
        assertEq(end.next, 0, "end.next != 0");

        // Next node for insertion is not initialized
        i += 1;
        List.Node memory next = list.get(i);
        assertTrue(!next.init, "next init");
        assertEq(next.prev, 0, "next.prev != 0");
        assertEq(next.next, 0, "next.next != 0");
        assertEq(next.val, 0, "next.val != 0");
    }

    function invariant_eq() public view {
        (, uint64 s, uint64 e, uint64 len) = list.ptr();

        uint256 n = h.len();
        assertEq(uint256(len), n, "handler: len");

        // Check vals
        uint256[] memory vals = list.vals();
        assertEq(uint256(len), vals.length, "handler: vals len");

        for (uint256 i = 0; i < n; i++) {
            assertEq(vals[i], h.vals(i), "handler: vals");
        }

        // Check find
        for (uint256 i = 0; i < n; i++) {
            uint256 val = h.vals(i);
            uint64 p = list.find(val);

            List.Node memory prev = list.get(p);

            assertLe(prev.val, val, "find: prev val");

            if (i == 0) {
                assertEq(p, 0, "find: p != 0");
                assertTrue(!prev.init, "find: prev init");
            } else {
                if (p != 0) {
                    assertTrue(prev.init, "find: prev not init");
                }
            }
        }

        // Check nodes
        uint64 c = s;
        uint64 p;
        for (uint256 i = 0; i < n; i++) {
            List.Node memory node = list.get(c);

            assertTrue(node.init, "nodes: node not init");
            assertEq(node.prev, p, "nodes: node.prev");
            assertEq(node.val, h.vals(i), "nodes: val");
            assertEq(c, h.ids(i), "nodes: id");

            if (node.prev != 0) {
                List.Node memory prev = list.get(node.prev);
                assertTrue(prev.init, "nodes: prev not init");
                assertLe(prev.val, node.val, "nodes: prev.val");
            }
            if (node.next != 0) {
                List.Node memory next = list.get(node.next);
                assertTrue(next.init, "nodes: next not init");
                assertLe(node.val, next.val, "nodes: next.val");
            }

            p = c;
            c = node.next;
        }
        assertEq(c, 0, "nodes: c != 0");
        assertEq(p, e, "nodes: p != e");
    }
}
