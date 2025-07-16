// 0x694DB9e4A598a4757e3f4FD8993CEA618F06E9da

import { ethers } from "ethers";
import * as dotenv from "dotenv";
dotenv.config();

// --- CONFIGURATION ---
// Set your CollectionFactory contract address
const FACTORY_ADDRESS = "0xf594D76eA6c2a6d10CE61bd847827b98f61B39a2"; // replace with your address

// The deployed collection address to check
const COLLECTION_ADDRESS_TO_CHECK = "0x694DB9e4A598a4757e3f4FD8993CEA618F06E9da"; // replace with your target

// Your RPC endpoint
const RPC_URL = process.env.XDC_RPC_URL || "https://rpc.xinfin.network";

// Minimal ABI for verifyCollection(address)
const abi = [
  "function verifyCollection(address collection) view returns (bool)"
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const factory = new ethers.Contract(FACTORY_ADDRESS, abi, provider);

  const isDeployed = await factory.verifyCollection(COLLECTION_ADDRESS_TO_CHECK);

  if (isDeployed) {
    console.log(`✅ Collection ${COLLECTION_ADDRESS_TO_CHECK} is DEPLOYED.`);
  } else {
    console.log(`❌ Collection ${COLLECTION_ADDRESS_TO_CHECK} is NOT deployed by this factory.`);
  }
}

main().catch((err) => {
  console.error("Error:", err);
});
