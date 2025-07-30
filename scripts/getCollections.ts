import { ethers } from "ethers";

const FACTORY_ADDRESS = "0xC105A6Aeb049c5F585814bF6c7c991A5e363a96B";
const FACTORY_ABI = [
  "function getGameCollections(uint256) view returns (address[])"
];
const RPC_URL = process.env.XDC_RPC_URL;

// Paste your actual gameIds here:
const GAME_IDS = [
  211813189,
  3085878749,
  1742449488
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const factory = new ethers.Contract(FACTORY_ADDRESS, FACTORY_ABI, provider);

  for (const gameId of GAME_IDS) {
    const collections: string[] = await factory.getGameCollections(gameId);
    if (collections.length > 0) {
      console.log(`GameID: ${gameId} has collections:`);
      for (const addr of collections) {
        console.log(`  - ${addr}`);
      }
    } else {
      console.log(`GameID: ${gameId} has no collections.`);
    }
  }
}

main().catch(console.error);
