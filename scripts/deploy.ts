import { ethers, run, network } from "hardhat";

async function main(): Promise<void> {
  console.log("Deploying CollectionFactory contract...");

  // Get the ContractFactory and Signers
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const balance = await ethers.provider.getBalance(deployer.address);
  console.log(
    "Account balance:",
    ethers.formatEther(balance),
    network.name === "hardhat" ? "ETH (simulated)" : "ETH"
  );

  // Deploy CollectionFactory
  const deploymentFee = ethers.parseEther("0.001"); // 0.001 ETH deployment fee
  const feeRecipient = deployer.address; // Use deployer as fee recipient

  const CollectionFactory = await ethers.getContractFactory(
    "CollectionFactory"
  );
  const collectionFactory = await CollectionFactory.deploy(
    deploymentFee,
    feeRecipient
  );

  console.log("Transaction hash:", (await collectionFactory.deployTransaction()).hash);
  await collectionFactory.deploymentTransaction()?.wait(1);

  console.log(
    "CollectionFactory deployed to:",
    collectionFactory.target // .address for older versions
  );
  console.log(
    "Deployment fee set to:",
    ethers.formatEther(deploymentFee),
    "ETH"
  );
  console.log("Fee recipient:", feeRecipient);

  // Optional: verify contract if Etherscan API key is provided
  if (process.env.ETHERSCAN_API_KEY && network.name !== "hardhat") {
    console.log("Waiting for block confirmations...");
    await collectionFactory.deploymentTransaction()?.wait(6);

    console.log("Verifying contract...");
    try {
      await run("verify:verify", {
        address: collectionFactory.target,
        constructorArguments: [deploymentFee, feeRecipient],
      });
      console.log("Contract verified on Etherscan");
    } catch (error: any) {
      console.warn("Verification failed:", error.message || error);
    }
  }

  // Next steps
  console.log("\n=== DEPLOYMENT COMPLETE ===");
  console.log("Network:", network.name);
  console.log("Contract Address:", collectionFactory.target);
  console.log("Transaction Hash:", (await collectionFactory.deployTransaction()).hash);
  console.log("\n=== NEXT STEPS ===");
  console.log(
    "1. Update FACTORY_ADDRESS in src/hooks/useBlockchainDeploy.ts with:",
    collectionFactory.target
  );
  console.log(
    "2. Test the deployment by creating a collection through the admin panel"
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
