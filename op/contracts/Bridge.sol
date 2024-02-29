// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// L1Bridge -> L1StandardBridge -> CrossDomainMessenger (L1)
// L2Bridge -> L2StandardBridge -> CrossDomainMessenger (L2)

// Lock ERC20 on L1 and mint OPERC20 on L2
// ERC20 -> L1Bridge -> L1StandardBrige

// Burn OPERC20 on L2 and unlock ERC20 on L1
// OPERC20 -> L2Bridge -> L2StandardBridge

// 1. Deploy ERC20 on L1
// 2. Deploy OPERC20 on L2
// 3. Deploy L1Bridge on L1
// 4. Deploy L2Bridge on L2
// 5. Mint ERC20 and approve L1Bridge
// 6. Send ERC20 to L2
// 7. Check OPERC20 balance of L2Bridge
// 8. Withdraw OPERC20 on L2
// 9. Send ERC20 to L1
// 10. Check ERC20 balance of L1Bridge
// 11. Withdraw ERC20 on L1

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

// 0x9EC35f70d03b84a62E688a1aec525bCb73A9A4ED
contract L1Bridge {
    // 0xFBb0621E0B23b5478B630BD55a5f21f67730B0F1
    address public immutable l1_bridge;
    // 0x230c88c6EdaA9D19Ec904ab75b0D506Cbd81CaF6
    address public immutable l1_token;
    // 0xd0e76D0ea91f25Ce0Ad3e48e3CeD94d98806Fe6d
    address public immutable l2_token;

    constructor(address _l1_bridge, address _l1_token, address _l2_token) {
        l1_bridge = _l1_bridge;
        l1_token = _l1_token;
        l2_token = _l2_token;

        // TODO: infinite approval is safe?
        IERC20(l1_token).approve(l1_bridge, type(uint256).max);
    }

    // Deposit L1 -> L2
    // remote_addr = L2Bridge
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

// 0x01d04e9A7480a4E62C953737753697D5D73E6D3e
contract L2Bridge {
    // 0x4200000000000000000000000000000000000010
    address public immutable l2_bridge;
    address public immutable l1_token;
    address public immutable l2_token;

    constructor(address _l2_bridge, address _l1_token, address _l2_token) {
        l2_bridge = _l2_bridge;
        l1_token = _l1_token;
        l2_token = _l2_token;

        // TODO: infinite approval is safe?
        IERC20(l2_token).approve(l2_bridge, type(uint256).max);
    }

    // Withdraw L2 -> L1
    // remote_addr = L1Bridge
    function sendToL1(address remote_addr, uint256 amount) external {
        // TODO: how to cancel bridge transfer?
        IERC20(l2_token).transferFrom(msg.sender, address(this), amount);
        IL1StandardBridge(l2_bridge).bridgeERC20To({
            local_token: l2_token,
            remote_token: l1_token,
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
