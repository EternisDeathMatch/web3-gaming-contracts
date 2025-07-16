import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Load environment variables from .env file
const RPC_URL = process.env.XDC_RPC_URL;
const CONTRACT_ADDRESS = "0x4999c4e3ef1e275640cfb50a34a64dc1184eda06";

if (!RPC_URL || !CONTRACT_ADDRESS) {
  console.error("Please set RPC_URL and CONTRACT_ADDRESS in your .env file");
  process.exit(1);
}

// ABI for GameNFTCollection (only relevant fragments)
const abi = [
  "function getCurrentTokenId() view returns (uint256)",
  "function tokenURI(uint256 tokenId) view returns (string)"
];

async function main() {
  // Connect to Ethereum provider
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // Instantiate the contract
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, provider);

  // Fetch the current token ID count
  const currentCount = await contract.getCurrentTokenId();
  const totalMinted = currentCount;
  console.log(`Total minted tokens: ${totalMinted}`);

  if (totalMinted === 0) {
    console.log("No tokens minted yet.");
    return;
  }

  console.log("Fetching token URIs...");
  for (let tokenId = 0; tokenId < totalMinted; tokenId++) {
    try {
      const uri: string = await contract.tokenURI(tokenId);
      console.log(`Token #${tokenId}: ${uri}`);
    } catch (error) {
      console.error(`Error fetching tokenURI for ID ${tokenId}:`, error);
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
