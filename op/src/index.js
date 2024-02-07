const optimism = require("@eth-optimism/sdk")
const ethers = require("ethers")

const PRIVATE_KEY = process.env.PRIVATE_KEY
const L2_TX = process.env.L2_TX

const L1_RPC = "https://rpc.ankr.com/eth_sepolia"
const L2_RPC = "https://sepolia.optimism.io"
// 11155111 for Sepolia, 1 for Ethereum
const L1_CHAIN_ID = 11155111
// 11155420 for OP Sepolia, 10 for OP Mainnet
const L2_CHAIN_ID = 11155420

async function main() {
  // Create RPC providers and wallet
  const l1_provider = new ethers.providers.StaticJsonRpcProvider(L1_RPC)
  const l2_provider = new ethers.providers.StaticJsonRpcProvider(L2_RPC)
  const l1_wallet = new ethers.Wallet(PRIVATE_KEY, l1_provider)
  const l2_wallet = new ethers.Wallet(PRIVATE_KEY, l2_provider)

  // Create CrossChainMessenger instance
  const messenger = new optimism.CrossChainMessenger({
    l1ChainId: L1_CHAIN_ID,
    l2ChainId: L2_CHAIN_ID,
    l1SignerOrProvider: l1_wallet,
    l2SignerOrProvider: l2_wallet,
  })

  // Wait until message is ready to prove
  console.log("Wait for message status...")
  await messenger.waitForMessageStatus(
    L2_TX,
    optimism.MessageStatus.READY_TO_PROVE
  )

  // Prove the message on L1
  console.log("Prove message on L1...")
  await messenger.proveMessage(L2_TX)

  // Wait until the message is ready for relay
  // NOTE:
  // This can only happen after the fault proof period has elapsed.
  // On OP Sepolia, this is only a few seconds.
  // On OP Mainnet, this takes 7 days.
  console.log("Wait for message status...")
  await messenger.waitForMessageStatus(
    L2_TX,
    optimism.MessageStatus.READY_FOR_RELAY
  )

  // Relay the message on L1
  console.log("Finalize...")
  await messenger.finalizeMessage(L2_TX)

  // Wait until the message is relayed
  console.log("Wait for message status...")
  await messenger.waitForMessageStatus(L2_TX, optimism.MessageStatus.RELAYED)
}

main()
