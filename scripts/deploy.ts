import { ethers, run, network } from "hardhat";
//0xf252C445522BA5d345554953B5de7409161771DE
async function main(): Promise<void> {
  console.log("Deploying CollectionFactory contract...");

  // Get signer
  const [deployer] = await ethers.getSigners();
  console.log("Deployer address:", await deployer.getAddress());
  const balance = await ethers.provider.getBalance(await deployer.getAddress());
  console.log(
    "Account balance:",
    ethers.formatEther(balance),
    network.name === "hardhat" ? "ETH (simulated)" : "ETH"
  );

  // Prepare deployment parameters
  const deploymentFee = ethers.parseEther("0.001"); // 0.001 ETH
  const feeRecipient = deployer.getAddress();

  // Deploy
  const Factory = await ethers.getContractFactory("CollectionFactory");
  const collectionFactory = await Factory.deploy(deploymentFee, feeRecipient);

  // Log transaction hash and wait for on-chain deployment
  const tx = collectionFactory.deploymentTransaction();
  console.log("Transaction hash:", tx!.hash);
  await collectionFactory.waitForDeployment();

  console.log("CollectionFactory deployed to:", collectionFactory.target);
  console.log(
    "Deployment fee set to:",
    ethers.formatEther(deploymentFee),
    "ETH"
  );
  console.log("Fee recipient:", feeRecipient);

  // Optional verification
  if (process.env.ETHERSCAN_API_KEY && network.name !== "hardhat") {
    console.log("Waiting for confirmations...");
    await tx!.wait(6);

    console.log("Verifying contract on Etherscan...");
    try {
      await run("verify:verify", {
        address: collectionFactory.target,
        constructorArguments: [deploymentFee, feeRecipient],
      });
      console.log("✅ Verification successful");
    } catch (error: any) {
      console.warn("⚠ Verification error:", error.message || error);
    }
  }

  // Final summary
  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log("Network:", network.name);
  console.log("Contract Address:", collectionFactory.target);
  console.log("Transaction Hash:", tx!.hash);
  console.log("\nNext steps:");
  console.log(
    "1) Update FACTORY_ADDRESS in front-end with:",
    collectionFactory.target
  );
  console.log("2) Test collection creation via admin panel");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
