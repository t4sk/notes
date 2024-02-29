// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// 1. Deploy ERC20 on L1
// 2. Deploy OPERC20 on L2
// 3. Deploy L1Bridge on L1
// 4. Deploy L2Bridge on L2
// 5. Mint and approve L1Bridge
// 6. Send ERC20 to L2
// 7. Withdraw on L2
// 8. Send ERC20 to L1
// 9. Withdraw on L1

interface IL1StandardBridge {
    // Calls same internal function as bridgeERC20To
    function depositERC20To(
        address l1_token,
        address l2_token,
        address to,
        uint256 amount,
        uint32 min_gas_limit,
        bytes calldata data
    ) external;

    function bridgeERC20To(
        address local_token,
        address remote_token,
        address to,
        uint256 amount,
        uint32 min_gas_limit,
        bytes calldata data
    ) external;
}

interface IL2StandardBridge {
    // Calls same internal function as bridgeERC20To
    function withdrawTo(address l2_token, address to, uint256 amount, uint32 min_gas_limit, bytes calldata data)
        external;

    function bridgeERC20To(
        address local_token,
        address remote_token,
        address to,
        uint256 amount,
        uint32 min_gas_limit,
        bytes calldata data
    ) external;
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address dst, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address src, address dst, uint256 amount) external returns (bool);
}

contract L1Bridge {
    address public immutable l1_bridge;
    address public immutable l2_bridge;
    // TODO: deploy OPMintableERC20
    address public immutable l1_token;
    address public immutable l2_token;

    constructor(address _l1_bridge, address _l2_bridge, address _l1_token, address _l2_token) {
        l1_bridge = _l1_bridge;
        l2_bridge = _l2_bridge;
        l1_token = _l1_token;
        l2_token = _l2_token;

        // TODO: infinite approval is safe?
        IERC20(l1_token).approve(l1_bridge, type(uint256).max);
    }

    // Deposit L1 -> L2
    function sendToL2(address remote_addr, uint256 amount) external {
        // TODO: how to cancel bridge transfer?
        IERC20(l1_token).transferFrom(msg.sender, address(this), amount);
        IL1StandardBridge(l1_bridge).bridgeERC20To({
            local_token: l1_token,
            remote_token: l2_token,
            to: remote_addr,
            amount: amount,
            // TODO: what should go here?
            min_gas_limit: 200000,
            data: ""
        });
    }

    function withdraw(address token) external {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, bal);
    }
}

contract L2Bridge {
    address public immutable l1_bridge;
    address public immutable l2_bridge;
    // TODO: deploy OPMintableERC20
    address public immutable l1_token;
    address public immutable l2_token;

    constructor(address _l1_bridge, address _l2_bridge, address _l1_token, address _l2_token) {
        l1_bridge = _l1_bridge;
        l2_bridge = _l2_bridge;
        l1_token = _l1_token;
        l2_token = _l2_token;

        // TODO: infinite approval is safe?
        IERC20(l2_token).approve(l2_bridge, type(uint256).max);
    }

    // Withdraw L2 -> L1
    function sendToL1(address remote_addr, uint256 amount) external {
        // TODO: how to cancel bridge transfer?
        IERC20(l2_token).transferFrom(msg.sender, address(this), amount);
        IL2StandardBridge(l2_bridge).withdrawTo({
            l2_token: l2_token,
            to: remote_addr,
            amount: amount,
            // TODO: what should go here?
            min_gas_limit: 200000,
            data: ""
        });
    }

    function withdraw(address token) external {
        uint256 bal = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, bal);
    }
}
