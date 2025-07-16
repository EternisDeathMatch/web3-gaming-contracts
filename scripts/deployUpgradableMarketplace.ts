import { ethers, upgrades, network } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying GameMarketplace...");
  console.log("Deployer address:", deployer.address);

  // Set your platform fee recipient here. For test, use deployer.
  const feeRecipient = deployer.address;

  // Get contract factory
  const Marketplace = await ethers.getContractFactory("GameMarketplace");

  // Deploy proxy (UUPS)
  const marketplace = await upgrades.deployProxy(
    Marketplace,
    [feeRecipient], // args for initialize()
    { kind: "uups" }
  );
  await marketplace.waitForDeployment();

  const proxyAddress = await marketplace.getAddress();
  const implAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);

  console.log(`GameMarketplace deployed as UUPS proxy to: ${proxyAddress}`);
  console.log(`Implementation address: ${implAddress}`);
  console.log("Network:", network.name);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
// GameMarketplace deployed as UUPS proxy to: 0x06e0e6511BaA2327DD7656557327258bDB372DD7
// Implementation address: 0xa00d3A8a2C71ed5865164Dbc4A60A60bf504459b
// Network: xdc