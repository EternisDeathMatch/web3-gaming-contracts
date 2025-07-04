
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    polygon: {
      url: "https://polygon-rpc.com/",
      accounts: [], // Add your private keys here for deployment
      gasPrice: 30000000000 // 30 gwei
    },
    mumbai: {
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts: [], // Add your private keys here for deployment
      gasPrice: 20000000000 // 20 gwei
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      accounts: [],
      gasPrice: 20000000000
    },
    xdc: {
      url: process.env.XDC_RPC_URL || "https://rpc.xinfin.network",
      chainId: 50,
      accounts: ["0x409c4cef75889e2c268937fa43c87b2d782ec3777a3988a6dcb65147e4a84926"],
    },
  },
  etherscan: {
    apiKey: {
      polygon: "YOUR_POLYGONSCAN_API_KEY",
      bsc: "YOUR_BSCSCAN_API_KEY"
    }
  }
};
