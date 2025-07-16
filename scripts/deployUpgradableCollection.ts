import { ethers, run, network, upgrades } from "hardhat";

async function main(): Promise<void> {
  console.log("Deploying CollectionFactory contract...");

  // Get deployer
  const [deployer] = await ethers.getSigners();
  const balance = await ethers.provider.getBalance(await deployer.getAddress());
  console.log("Deployer address:", await deployer.getAddress());
  console.log(
    "Account balance:",
    ethers.formatEther(balance),
    network.name === "hardhat" ? "ETH (simulated)" : "ETH"
  );

  // Prepare deployment parameters
  const deploymentFee = ethers.parseEther("0.001"); // 0.001 ETH
  const feeRecipient = await deployer.getAddress();

  // Deploy as UUPS proxy
  const Factory = await ethers.getContractFactory("CollectionFactory");
  const collectionFactory = await upgrades.deployProxy(
    Factory,
    [deploymentFee, feeRecipient],
    { kind: "uups" }
  );
  await collectionFactory.waitForDeployment();

  // Transaction hash (deployProxy returns the proxy contract, not the implementation)
  // So .deploymentTransaction() is not available, use receipt from the proxy deployment:
  const receipt = await ethers.provider.getTransactionReceipt(collectionFactory.deploymentTransaction()!.hash);

  console.log("CollectionFactory proxy deployed to:", collectionFactory.target);
  console.log(
    "Deployment fee set to:",
    ethers.formatEther(deploymentFee),
    "ETH"
  );
  console.log("Fee recipient:", feeRecipient);
  if (receipt) {
    console.log("Transaction hash:", receipt.hash);
  }

  // (Optional) Print Implementation address
  const implAddress = await upgrades.erc1967.getImplementationAddress(collectionFactory.target as string);
  console.log("Implementation contract address:", implAddress);

  // Final summary
  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log("Network:", network.name);
  console.log("Proxy Address:", collectionFactory.target);
  console.log("Implementation Address:", implAddress);

  console.log("\nNext steps:");
  console.log("1) Update FACTORY_ADDRESS in front-end with:", collectionFactory.target);
  console.log("2) Test collection creation via admin panel");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
// Fee recipient: 0x20F67281413FBFfDea3BBee8d896335689C38648
// Transaction hash: 0xac26e496af38f3c9a62d6b0ea0310848e3f174d9be53eaa63276e967e7819b50
// Implementation contract address: 0x653EF7DBC87A56E0Dd62b28b2C3E89E9d252795E

// === DEPLOYMENT COMPLETE ===
// Network: xdc
// Proxy Address: 0xf594D76eA6c2a6d10CE61bd847827b98f61B39a2
// Implementation Address: 0x653EF7DBC87A56E0Dd62b28b2C3E89E9d252795E
