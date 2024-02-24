const optimism = require("@eth-optimism/sdk")
const ethers = require("ethers")

const PRIVATE_KEY = process.env.PRIVATE_KEY

const L1_RPC = "https://rpc.ankr.com/eth_sepolia"
const L2_RPC = "https://sepolia.optimism.io"
// 11155111 for Sepolia, 1 for Ethereum
const L1_CHAIN_ID = 11155111
// 11155420 for OP Sepolia, 10 for OP Mainnet
const L2_CHAIN_ID = 11155420

const L1_TOKEN = "0x5589BB8228C07c4e15558875fAf2B859f678d129"
const L2_TOKEN = "0xD08a2917653d4E460893203471f0000826fb4034"

const ERC20_ABI = [
  {
    constant: true,
    inputs: [{ name: "_owner", type: "address" }],
    name: "balanceOf",
    outputs: [{ name: "balance", type: "uint256" }],
    type: "function",
  },
  {
    inputs: [],
    name: "faucet",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
]

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

  const l1_token = new ethers.Contract(L1_TOKEN, ERC20_ABI, l1_wallet)
  const l2_token = new ethers.Contract(L2_TOKEN, ERC20_ABI, l2_wallet)

  {
    // Get L1 token
    const tx = await l1_token.faucet()
    await tx.wait()
    console.log(
      "L1 ERC20 balance",
      (await l1_token.balanceOf(l1_wallet.address)).toString()
    )
  }

  const amount = 1000000000000000000n

  {
    console.log("Approval...")
    // TODO: why l1 and l2 approval?
    const tx = await messenger.approveERC20(l1_token, l2_token, amount)
    await tx.wait()
  }

  console.log("Deposit...")
  const tx = await messenger.depositERC20(l1_token, l2_token, amount)
  await tx.wait()

  console.log("TX", tx.hash)

  // Wait until message is ready to prove
  console.log("Wait for message status...")
  await messenger.waitForMessageStatus(tx.hash, optimism.MessageStatus.RELAYED)

  console.log(
    "L2 ERC20 balance",
    (await l2_token.balanceOf(l2_wallet.address)).toString()
  )
}

main()
