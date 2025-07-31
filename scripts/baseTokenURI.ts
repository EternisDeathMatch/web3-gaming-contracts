import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Load environment variables from .env file
const RPC_URL = process.env.XDC_RPC_URL;
const CONTRACT_ADDRESS = "0x996f91A2795D19eBbEdf9D71E22D765886777746";

if (!RPC_URL || !CONTRACT_ADDRESS) {
  console.error("Please set XDC_RPC_URL and CONTRACT_ADDRESS in your .env file");
  process.exit(1);
}

// ABI fragment for baseTokenURI getter
const abi = [
  "function baseTokenURI() view returns (string)"
];

async function main() {
  // Connect to XDC provider
  const provider = new ethers.JsonRpcProvider(RPC_URL);

  // Instantiate the contract
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, provider);

  // Fetch the base URI
  try {
    const baseURI: string = await contract.baseTokenURI();
    console.log(`Base Token URI: ${baseURI}`);
  } catch (error) {
    console.error("Error fetching baseTokenURI:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
