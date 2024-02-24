```shell
# Send message from L2 to L1
L2_TX=0x3592c40fbd8577993e307b0c5ed534482c5dc5a3bb996d540300b8542a5bf85f
env $(cat .env) L2_TX=$L2_TX node src/index.js

# Deposit ERC20 from L1 to L2
env $(cat .env) node src/erc20_deposit.js

# Withdraw ERC20 from L2 to L1
env $(cat .env) node src/erc20_withdraw.js
```

Contracts

https://github.com/ethereum-optimism/optimism/tree/develop/packages/contracts-bedrock/src
