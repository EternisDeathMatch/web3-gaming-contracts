import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const RPC_URL = process.env.XDC_RPC_URL;
const PRIVATE_KEY = process.env.PRIVATE_KEY!;
const MARKETPLACE_CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS!;
const NFT_CONTRACT = process.env.NFT_CONTRACT!; // Your NFT contract address

if (
  !RPC_URL ||
  !PRIVATE_KEY ||
  !MARKETPLACE_CONTRACT_ADDRESS ||
  !NFT_CONTRACT
) {
  console.error(
    "Please set XDC_RPC_URL, PRIVATE_KEY, CONTRACT_ADDRESS, NFT_CONTRACT in your .env file"
  );
  process.exit(1);
}

// ABI fragment for batchCancelListings
const abi = [
  "function batchCancelListings(address nftContract, uint256[] calldata tokenIds) external",
];

// Example token IDs to cancel (replace with your own, or read from elsewhere)
const tokenIdsToCancel = [0, 1, 2, 3, 4, 5]; // Example: [1, 2, 3]

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  const contract = new ethers.Contract(
    MARKETPLACE_CONTRACT_ADDRESS,
    abi,
    wallet
  );

  try {
    const tx = await contract.batchCancelListings(
      NFT_CONTRACT,
      tokenIdsToCancel
    );
    console.log("Transaction sent:", tx.hash);

    const receipt = await tx.wait();
    console.log("Batch cancel confirmed in block:", receipt.blockNumber);
  } catch (error) {
    console.error("Error cancelling listings:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
