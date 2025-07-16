import { ethers, run, network } from "hardhat";

async function main(): Promise<void> {
  console.log("Deploying GameMarketplace contract...");

  // Fetch deployer
  const [deployer] = await ethers.getSigners();
  const deployerAddress = await deployer.getAddress();
  console.log("Deployer address:", deployerAddress);

  // Print balance
  const balance = await ethers.provider.getBalance(deployerAddress);
  console.log(
    "Account balance:",
    ethers.formatEther(balance),
    network.name === "hardhat" ? "ETH (simulated)" : "ETH"
  );

  // Define constructor argument
  const feeRecipient = deployerAddress;

  // Deploy GameMarketplace
  const Factory = await ethers.getContractFactory("GameMarketplace");
  const marketplace = await Factory.deploy(feeRecipient) as Awaited<ReturnType<typeof Factory.deploy>>;

  // Deployment transaction
  const tx = marketplace.deploymentTransaction();
  console.log("Transaction hash:", tx!.hash);

  // Wait for network to mine deployment
  await marketplace.waitForDeployment();
  console.log("GameMarketplace deployed to:", marketplace.target);

  // Optional Etherscan verification
  if (process.env.ETHERSCAN_API_KEY && network.name !== "hardhat") {
    console.log("Waiting for 6 confirmations...");
    await tx!.wait(6);
    console.log("Verifying contract on Etherscan...");
    try {
      await run("verify:verify", {
        address: marketplace.target,
        constructorArguments: [feeRecipient],
      });
      console.log("✅ Verification successful");
    } catch (err: any) {
      console.warn("⚠ Verification failed:", err.message || err);
    }
  }

  // Summary
  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log("Network:", network.name);
  console.log("Contract Address:", marketplace.target);
  console.log("Transaction Hash:", tx!.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


  //
//   === DEPLOYMENT COMPLETE ===
// Network: xdc
// Contract Address: 0xabb3c92635f53d46Eeb18f7b43348aE3847963E2
// Transaction Hash: 0x30c5754402b5c29ab48be71fa81c5e13630b2f35795ff213b1c52e4384ad3436