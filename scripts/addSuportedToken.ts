// scripts/addSupportedXDC.ts
import { ethers, network } from "hardhat";
import { GameMarketplace } from "../typechain";

async function main() {
  // 1) Configure these two constants:
  const MARKETPLACE_ADDRESS = "0xabb3c92635f53d46Eeb18f7b43348aE3847963E2";
  const XDC_TOKEN_ADDRESS   = "0xYourXdaiTokenAddressHere"; // e.g. the XDC token contract

  // 2) Load your deployer
  const [deployer] = await ethers.getSigners();
  console.log("⛏️  Adding supported token on", network.name);
  console.log("    Deployer:", await deployer.getAddress());

  // 3) Attach to the marketplace
  const Marketplace = await ethers.getContractFactory("GameMarketplace");
  const marketplace = Marketplace.attach(MARKETPLACE_ADDRESS) as GameMarketplace;

  // 4) Call addSupportedToken

  const tx = await marketplace.addSupportedToken(XDC_TOKEN_ADDRESS);
  console.log("🔃 Transaction submitted:", tx.hash);
  await tx.wait();
  console.log("✅ XDC token added as supported payment token!");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
