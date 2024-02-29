// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./ERC20.sol";

interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

interface IOptimismMintableERC20 is IERC165 {
    function remoteToken() external view returns (address);
    // Local bridge
    function bridge() external view returns (address);
    function mint(address dst, uint256 amount) external;
    function burn(address src, uint256 amount) external;
}

contract OPERC20 is ERC20, IOptimismMintableERC20 {
    address public immutable remoteToken;
    address public immutable bridge;

    event Mint(address indexed account, uint256 amount);
    event Burn(address indexed account, uint256 amount);

    modifier onlyBridge() {
        require(msg.sender == bridge, "not bridge");
        _;
    }

    constructor(address _remoteToken, address _bridge) {
        remoteToken = _remoteToken;
        bridge = _bridge;
    }

    function supportsInterface(bytes4 _interfaceId) external pure returns (bool) {
        bytes4 iface1 = type(IERC165).interfaceId;
        // Interface corresponding to the legacy L2StandardERC20.
        // bytes4 iface2 = type(ILegacyMintableERC20).interfaceId;
        // Interface corresponding to the updated OptimismMintableERC20 (this contract).
        bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
        return _interfaceId == iface1 || _interfaceId == iface3;
    }

    function mint(address dst, uint256 amount) public override(ERC20, IOptimismMintableERC20) onlyBridge {
        mint(dst, amount);
        emit Mint(dst, amount);
    }

    function burn(address src, uint256 amount) public override(ERC20, IOptimismMintableERC20) onlyBridge {
        burn(src, amount);
        emit Burn(src, amount);
    }
}
