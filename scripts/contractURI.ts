import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const RPC_URL = process.env.XDC_RPC_URL;
const CONTRACT_ADDRESS = process.env.CONTRACT_ADDRESS! ;

if (!RPC_URL || !CONTRACT_ADDRESS) {
  console.error("Please set XDC_RPC_URL and CONTRACT_ADDRESS in your .env file");
  process.exit(1);
}

// ABI fragment for contractURI getter
const abi = [
  "function contractURI() view returns (string)"
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, provider);

  try {
    const contractUri = await contract.contractURI();
    console.log(`Contract URI: ${contractUri}`);
  } catch (error) {
    console.error("Error fetching contractURI:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
