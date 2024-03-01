// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// L1    | L2
// ERC20 | OPERC20 (OptimismMintableERC20)

// Send ERC20 from L1 to L2
// Lock ERC20 on L1StandardBrige
// -> CrossDomainMessenger (L1)
// -> L2StandardBrige (L2)
// -> Mint OPERC20 (L2)

// Send ERC20 from L2 to L1
// Burn OPERC20 by L2StandardBrige
// -> CrossDomainMessenger (L2)
// -> Unlock ERC20 on L1StandardBridge

// 1. Deploy ERC20 on L1
// 2. Deploy OPERC20 on L2
// 3. Deploy L1Bridge on L1
// 4. Deploy L2Bridge on L2
// 5. Mint ERC20 and approve L1Bridge
// 6. Send ERC20 to L2
// 7. Check OPERC20 balance of L2Bridge
// 8. Withdraw OPERC20 on L2
// 9. Approve OPERC20 for L2Bridge and send ERC20 to L1
// 10. Check ERC20 balance of L1Bridge
// 11. Withdraw ERC20 on L1
// 12. Check finalize tx and token transfer

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

// 0xB0b0F34273940594b6E637Ca9e8fdc527061c423
contract L1Bridge {
    // 0xFBb0621E0B23b5478B630BD55a5f21f67730B0F1
    address public immutable l1_op_bridge;
    // 0x93F74d0730758094cE8Cb2ee1f6999A7cD38e75a 
    address public immutable l1_token;
    // 0x27d48bDF3238DFd85023139f0400eFa4B646b474
    address public immutable l2_token;

    constructor(address _l1_op_bridge, address _l1_token, address _l2_token) {
        l1_op_bridge = _l1_op_bridge;
        l1_token = _l1_token;
        l2_token = _l2_token;

        // TODO: infinite approval is safe?
        IERC20(l1_token).approve(l1_op_bridge, type(uint256).max);
    }

    // Deposit L1 -> L2
    // remote_addr = L2Bridge
    function sendToL2(address remote_addr, uint256 amount) external {
        // TODO: how to cancel bridge transfer?
        IERC20(l1_token).transferFrom(msg.sender, address(this), amount);
        IL1StandardBridge(l1_op_bridge).bridgeERC20To({
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

// 0x31B136e2d1fa077e6e6b629b05B1E0360835e5B8
// Withdraw from L2 to L1 tx
// https://optimism-sepolia.blockscout.com/tx/0x915f467d322682f0bb1bfe332a9099dcef8dbd2acc4335b0d653cb5d255b655b
contract L2Bridge {
    // 0x4200000000000000000000000000000000000010
    address public immutable l2_op_bridge;
    address public immutable l1_token;
    address public immutable l2_token;

    constructor(address _l2_op_bridge, address _l1_token, address _l2_token) {
        l2_op_bridge = _l2_op_bridge;
        l1_token = _l1_token;
        l2_token = _l2_token;

        // TODO: infinite approval is safe?
        IERC20(l2_token).approve(l2_op_bridge, type(uint256).max);
    }

    // Withdraw L2 -> L1
    // remote_addr = L1Bridge
    function sendToL1(address remote_addr, uint256 amount) external {
        // TODO: how to cancel bridge transfer?
        IERC20(l2_token).transferFrom(msg.sender, address(this), amount);
        IL1StandardBridge(l2_op_bridge).bridgeERC20To({
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
