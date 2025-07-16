import { ethers } from "hardhat";

// Replace with your deployed addresses
const FACTORY_ADDRESS = "0xf594D76eA6c2a6d10CE61bd847827b98f61B39a2";
const COLLECTION_ADDRESS = "0x694DB9e4A598a4757e3f4FD8993CEA618F06E9da";
const TEST_BASE_URI = "https://rpc.xinfin.network"; // Can be anything

async function main() {
  const [signer] = await ethers.getSigners();

  // Attach contracts
  const factory = await ethers.getContractAt("CollectionFactory", FACTORY_ADDRESS, signer);
  const collection = await ethers.getContractAt("GameNFTCollection", COLLECTION_ADDRESS, signer);

  // 1. Check isDeployedCollection
  const isDeployed = await factory.isDeployedCollection(COLLECTION_ADDRESS);
  console.log(`isDeployedCollection: ${isDeployed}`);

  // 2. Check if signer is Factory owner
  const factoryOwner = await factory.owner();
  const isFactoryOwner = signer.address.toLowerCase() === factoryOwner.toLowerCase();
  console.log(`Signer is Factory owner: ${isFactoryOwner} (${factoryOwner})`);

  // 3. Check ADMIN_ROLE in Collection
  const ADMIN_ROLE = await collection.ADMIN_ROLE();
  const hasAdminRole = await collection.hasRole(ADMIN_ROLE, signer.address);
  console.log(`Signer has ADMIN_ROLE in collection: ${hasAdminRole}`);

  // 4. Optional: Try a static call for setBaseTokenURI
  let canSetBaseURI = false;
  try {
    // This is a static call by default in ethers v6!
    await collection.setBaseTokenURI.staticCall(TEST_BASE_URI);
    canSetBaseURI = true;
  } catch (e) {
    canSetBaseURI = false;
    console.log(`setBaseTokenURI.staticCall would revert:`, (e as Error).message);
  }
  console.log(`Can call setBaseTokenURI: ${canSetBaseURI}`);

  // 5. Final verdict
  if (!isDeployed) {
    console.log("❌ This collection is not registered as deployed.");
  } else if (!isFactoryOwner && !hasAdminRole) {
    console.log("❌ Signer is neither Factory owner nor ADMIN_ROLE in collection.");
  } else if (!canSetBaseURI) {
    console.log("❌ setBaseTokenURI would revert. Check collection contract state/role.");
  } else {
    console.log("✅ All conditions are satisfied. setCollectionBaseURI should succeed.");
  }
}

main().catch(console.error);
