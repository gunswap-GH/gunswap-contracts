import 'dotenv/config'
import { HardhatUserConfig } from 'hardhat/config'
import '@nomicfoundation/hardhat-ethers'
import '@nomicfoundation/hardhat-chai-matchers'

// Unified project: contracts/core (solc 0.5.16) + contracts/router (solc 0.6.6).
// Hardhat picks the compiler per file from its pragma. Settings are pinned to the original upstream
// values so deployed bytecode (and CREATE2 pair addresses) stay consistent.
const optimizer = { enabled: true, runs: 999999 }

// 部署账户来自 .env 的 PRIVATE_KEY(带不带 0x 都接受);未设置时为空数组,
// 本地测试仍用 hardhat 内置账户,不受影响。
const rawKey = process.env.PRIVATE_KEY?.trim()
const accounts = rawKey ? [rawKey.startsWith('0x') ? rawKey : `0x${rawKey}`] : []

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      { version: '0.5.16', settings: { optimizer, evmVersion: 'istanbul' } },
      { version: '0.6.6', settings: { optimizer, evmVersion: 'istanbul' } },
      // 测试用带税代币(test-contracts/ETCToken)是 0.8.22 + OpenZeppelin
      { version: '0.8.22', settings: { optimizer: { enabled: true, runs: 200 } } }
    ]
  },
  networks: {
    hardhat: {
      // chainId 1 keeps the EIP-712 DOMAIN_SEPARATOR identical to the upstream tests
      chainId: 1,
      // large router contracts; lift the 24KB code-size limit on the test network
      allowUnlimitedContractSize: true
    },
    bsc: {
      url: process.env.BSC_RPC_URL?.trim() || 'https://bsc-dataseed.binance.org',
      chainId: 56,
      accounts
    },
    bscTestnet: {
      url: process.env.BSC_TESTNET_RPC_URL?.trim() || 'https://data-seed-prebsc-1-s1.binance.org:8545',
      chainId: 97,
      accounts
    }
  },
  mocha: { timeout: 60000 }
}

export default config
