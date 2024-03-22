pragma solidity ^0.8;

contract Decode {
  function decode_uint(bytes memory data) public pure returns (uint256) {
    return abi.decode(data, (uint256));
  }

  function decode_int(bytes memory data) public pure returns (int256) {
    return abi.decode(data, (int256));
  }
}
