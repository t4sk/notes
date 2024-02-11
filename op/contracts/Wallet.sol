// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// 1. Deploy L1 contract
// 2. Deploy L2 contract
// 3. Send ETH L1 -> L2
// 4. Check ETH balance on L2
// 5. Withdraw on L2
// 6. Send ETH L2 -> L1
// 7. Check ETH balance on L1
// 8. Withdraw on L1

interface ICrossDomainMessenger {
    function xDomainMessageSender() external view returns (address);
    function sendMessage(
        address target,
        bytes calldata message,
        uint32 gasLimit
    ) external payable;
}

contract Wallet {
    // ETH Sepolia messenger - L1 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef
    // OP Sepolia messenger  - L2 0x4200000000000000000000000000000000000007
    address public immutable MESSENGER;
    // L1 - 0xffC0F11c92F4E2e50b3f72Fd32BB3d034Ac77BDc
    // L2 - 0x15d97e464ed2D95cC7c7d8365681946b1d9b5DD9

    constructor(address messenger) payable {
        MESSENGER = messenger;
    }

    receive() external payable {}

    function send(address remote_wallet) external payable {
        ICrossDomainMessenger(MESSENGER).sendMessage{value: msg.value}({
            target: remote_wallet,
            message: "",
            gasLimit: 200000
        });
    }

    function get_balance() external view returns (uint256) {
        return address(this).balance;
    }

    function withdraw() external {
        (bool ok, ) = msg.sender.call{value: address(this).balance}("");
        require(ok, "call failed");
    }
}
