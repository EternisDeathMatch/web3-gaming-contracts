
# Smart Contract Deployment Guide

This directory contains the Solidity smart contracts for the Web3 Gaming Platform.

## Prerequisites

1. Node.js and npm installed
2. Hardhat development environment
3. Wallet with funds for deployment (testnet or mainnet)
4. RPC endpoint for your target network
5. (Optional) Block explorer API key for contract verification

## Setup

1. Install dependencies:
```bash
cd contracts
npm install
```

2. Configure your network settings in `hardhat.config.js`
3. Add your private key and API keys to environment variables

## Environment Variables

Create a `.env` file in the contracts directory with:

```env
# Private key of the deploying wallet (without 0x prefix)
PRIVATE_KEY=your_private_key_here

# Network RPC URLs
POLYGON_RPC_URL=https://polygon-rpc.com/
MUMBAI_RPC_URL=https://rpc-mumbai.maticvigil.com/
BSC_RPC_URL=https://bsc-dataseed.binance.org/
XDC_RPC_URL=https://rpc.xinfin.network

# Block explorer API keys for verification
POLYGONSCAN_API_KEY=your_polygonscan_api_key
BSCSCAN_API_KEY=your_bscscan_api_key
```

## Deployment

### 1. Compile Contracts
```bash
npx hardhat compile
```

### 2. Deploy to Testnet (Mumbai)
```bash
npx hardhat run scripts/deploy.js --network mumbai
```

### 3. Deploy to Mainnet (Polygon)
```bash
npx hardhat run scripts/deploy.js --network polygon
```

### 4. Deploy to Other Networks
```bash
# BSC Testnet
npx hardhat run scripts/deploy.js --network bscTestnet

# BSC Mainnet  
npx hardhat run scripts/deploy.js --network bsc

# XDC Network
npx hardhat run scripts/deploy.js --network xdc
```

## After Deployment

1. **Update Frontend**: Copy the deployed contract address and update `FACTORY_ADDRESS` in `src/hooks/useBlockchainDeploy.ts`

2. **Verify Contract** (optional but recommended):
```bash
npx hardhat run scripts/verify.js --network <network> <contractAddress> <deploymentFee> <feeRecipient>
```

3. **Test Deployment**: Use the admin panel to create a test collection and verify it deploys correctly

## Contract Addresses

Keep track of your deployed contracts:

### Testnets
- Mumbai (Polygon): `0x...`
- BSC Testnet: `0x...`

### Mainnets  
- Polygon: `0x...`
- BSC: `0x...`
- XDC: `0x...`

## Troubleshooting

### Common Issues

1. **Insufficient funds**: Ensure your wallet has enough native tokens (MATIC, BNB, XDC) for gas
2. **Network connection**: Verify your RPC URLs are working
3. **Private key format**: Remove '0x' prefix from private key in .env
4. **Gas estimation**: Some networks may require manual gas settings

### Gas Optimization

The contracts are optimized for gas efficiency:
- CollectionFactory: ~2.5M gas
- GameNFTCollection: ~3M gas per deployment

### Security

- Never commit private keys to version control
- Use testnet first before mainnet deployment
- Verify contracts on block explorers
- Test all functions after deployment
