import { ethers } from "hardhat";

// Replace these with your actual deployed addresses!
const FACTORY_ADDRESS = "0xf594D76eA6c2a6d10CE61bd847827b98f61B39a2";
const COLLECTION_ADDRESS = "0x694DB9e4A598a4757e3f4FD8993CEA618F06E9da";

async function main() {
  const [signer] = await ethers.getSigners();

  // Attach to the GameNFTCollection contract
  const collection = await ethers.getContractAt("GameNFTCollection", COLLECTION_ADDRESS, signer);

  // Get ADMIN_ROLE bytes32 value
  const ADMIN_ROLE = await collection.ADMIN_ROLE();

  // Check if Factory already has ADMIN_ROLE
  const alreadyAdmin = await collection.hasRole(ADMIN_ROLE, FACTORY_ADDRESS);
  console.log(`Factory already has ADMIN_ROLE: ${alreadyAdmin}`);

  if (alreadyAdmin) {
    console.log("✅ No action needed. Factory is already admin.");
    return;
  }

  // Grant ADMIN_ROLE to the Factory contract
  const tx = await collection.grantRole(ADMIN_ROLE, FACTORY_ADDRESS);
  console.log("Granting ADMIN_ROLE to Factory, tx hash:", tx.hash);
  await tx.wait();
  console.log("✅ ADMIN_ROLE granted to Factory on this collection!");
}

main().catch(console.error);
