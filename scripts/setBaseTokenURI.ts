import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

// Load environment variables
const RPC_URL = process.env.XDC_RPC_URL;
const PRIVATE_KEY = process.env.DEPLOYER_PRIVATE_KEY!;
const CONTRACT_ADDRESS = "0xDdBd14c44bfad3B3E8802CD8dcA5Cdc02BEEDbb1";

if (!RPC_URL || !PRIVATE_KEY || !CONTRACT_ADDRESS) {
  console.error(
    "Please set XDC_RPC_URL, PRIVATE_KEY, and CONTRACT_ADDRESS in your .env file"
  );
  process.exit(1);
}

// Expect new base URI as command-line argument
const newBaseURI =
  "https://wrnjajqjwjldmnerdbxc.supabase.co/storage/v1/object/public/nft-metadata/0xDdBd14c44bfad3B3E8802CD8dcA5Cdc02BEEDbb1/";
if (!newBaseURI) {
  console.error("Usage: ts-node setBaseTokenURI.ts <newBaseURI>");
  process.exit(1);
}

// ABI fragment for setBaseTokenURI
const abi = [
  "function ADMIN_ROLE() view returns (bytes32)",
  "function hasRole(bytes32 role, address account) view returns (bool)",
  "function setBaseTokenURI(string newBaseURI) external",
];
async function main() {
  // Connect to XDC provider and signer
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  // Instantiate the contract with signer
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, wallet);
  const role = await contract.ADMIN_ROLE();
  console.log("My address:", await wallet.getAddress());
  console.log(
    "Has ADMIN_ROLE?",
    await contract.hasRole(role, await wallet.getAddress())
  );
  console.log(`Sending transaction to set baseTokenURI to: ${newBaseURI}`);
  try {
    const tx = await contract.setBaseTokenURI(newBaseURI);
    console.log("Transaction submitted. Hash:", tx.hash);

    // Wait for confirmation
    const receipt = await tx.wait();
    console.log(
      `Transaction confirmed in block ${receipt.blockNumber}. Status: ${receipt.status}`
    );
  } catch (err) {
    console.error("Error calling setBaseTokenURI:", err);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
