// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// 1. Op faucet and network setup
// 2. Deploy L2 contract
// 3. Deploy L1 contract
// 4. Set L1 greeter on L2
// 5. Set L2 greeter on L1
// 6. Send message to L2
// 7. Query message on L2 (sender = account)
// 8. Send message to L1
// 9. Query message on L1 (sender = account)

interface ICrossDomainMessenger {
    function xDomainMessageSender() external view returns (address);
    function sendMessage(
        address target,
        bytes calldata message,
        uint32 gasLimit
    ) external;
}

contract Greeter {
    // ETH Sepolia messenger - L1 0x58Cc85b8D04EA49cC6DBd3CbFFd00B4B8D6cb3ef
    // OP Sepolia messenger  - L2 0x4200000000000000000000000000000000000007
    address public immutable MESSENGER;
    // L1 - 0x0f3ed00838a3180E32707D5997184f7AEa00433d
    // L2 - 0x034D015DBA1A960CA3b92C8d0Bd21b84fbbc507f
    address public remote_greeter;
    mapping(address => string) public greetings;

    constructor(address messenger) {
        MESSENGER = messenger;
    }

    function set_remote_greeter(address _remote_greeter) external {
        remote_greeter = _remote_greeter;
    }

    function set(address sender, string memory greeting) external {
        require(
            msg.sender == MESSENGER,
            "Greeter: Caller must be the CrossDomainMessenger"
        );
        require(
            ICrossDomainMessenger(MESSENGER).xDomainMessageSender() == remote_greeter,
            "Greeter: Remote sender must be the remote greeter"
        );

        greetings[sender] = greeting;
    }

    function send(string memory greeting) external {
        ICrossDomainMessenger(MESSENGER).sendMessage({
            target: remote_greeter,
            message: abi.encodeCall(
                this.set,
                (
                    msg.sender,
                    greeting
                )
            ),
            // TODO: gas fee
            gasLimit: 200000
        });
    }
}

// TODO: how is message relayed from ETH to OP?
// TODO: how is message relayed from OP to ETH?
// TODO: how to send ETH between L1 and L2
// TODO: how to send ERC20 between L1 and L2