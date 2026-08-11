// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.33;

uint256 constant HEIGHT = 3;

contract MerkleInc {
    uint256 public count;
    bytes32[HEIGHT] public zeros;
    bytes32[HEIGHT] public nodes;

    function hash(bytes32 x, bytes32 y) private pure returns (bytes32 z) {
        assembly {
            let ptr := mload(0x40)
            mstore(ptr, x)
            mstore(add(ptr, 0x20), y)
            z := keccak256(ptr, 0x40)
        }
    }

    constructor() {
        zeros[0] = bytes32(0);
        for (uint256 i = 0; i < HEIGHT - 1; i++) {
            zeros[i + 1] = hash(zeros[i], zeros[i]);
        }
    }

    function root() external view returns (bytes32) {
        bytes32 h;
        uint256 k = count;

        for (uint256 i = 0; i < HEIGHT; i++) {
            if ((k & 1) == 1) {
                h = hash(nodes[i], h);
            } else {
                h = hash(h, zeros[i]);
            }
            k >>= 1;
        }

        return h;
    }

    function insert(bytes32 x) external {
        require(count < 2 ** HEIGHT - 1);

        count += 1;

        bytes32 h = x;
        uint256 k = count;

        for (uint256 i = 0; i < HEIGHT; i++) {
            if ((k & 1) == 1) {
                nodes[i] = h;
                return;
            } else {
                h = hash(nodes[i], h);
            }
            k >>= 1;
        }
    }
}
