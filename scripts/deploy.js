const hre = require("hardhat");

async function main() {
  console.log("Deploying CollectionFactory contract...");

  // Get the ContractFactory and Signers
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Account balance:", hre.ethers.formatEther(balance), "ETH");

  // Deploy CollectionFactory
  const deploymentFee = hre.ethers.parseEther("0.001"); // 0.001 ETH deployment fee
  const feeRecipient = deployer.address; // Use deployer as fee recipient

  const CollectionFactory = await hre.ethers.getContractFactory(
    "CollectionFactory"
  );
  const collectionFactory = await CollectionFactory.deploy(
    deploymentFee,
    feeRecipient
  );

  await collectionFactory.waitForDeployment();

  console.log("CollectionFactory deployed to:", await collectionFactory.getAddress());
  console.log(
    "Deployment fee set to:",
    hre.ethers.formatEther(deploymentFee),
    "ETH"
  );
  console.log("Fee recipient:", feeRecipient);

  // // Verify contract on block explorer (if API key is provided)
  // if (process.env.ETHERSCAN_API_KEY) {
  //   console.log("Waiting for block confirmations...");
  //   await collectionFactory.deployTransaction.wait(6);

  //   console.log("Verifying contract...");
  //   try {
  //     await hre.run("verify:verify", {
  //       address: collectionFactory.address,
  //       constructorArguments: [deploymentFee, feeRecipient],
  //     });
  //   } catch (error) {
  //     console.log("Verification failed:", error.message);
  //   }
  // }

  // Save deployment info
  // const deploymentInfo = {
  //   network: hre.network.name,
  //   contractAddress: collectionFactory.address,
  //   deploymentFee: deploymentFee.toString(),
  //   feeRecipient: feeRecipient,
  //   deployer: deployer.address,
  //   blockNumber: collectionFactory.deployTransaction.blockNumber,
  //   transactionHash: collectionFactory.deployTransaction.hash,
  // };

  // console.log("\n=== DEPLOYMENT COMPLETE ===");
  // console.log("Network:", deploymentInfo.network);
  // console.log("Contract Address:", deploymentInfo.contractAddress);
  // console.log("Transaction Hash:", deploymentInfo.transactionHash);
  // console.log("\n=== NEXT STEPS ===");
  // console.log(
  //   "1. Update FACTORY_ADDRESS in src/hooks/useBlockchainDeploy.ts with:",
  //   deploymentInfo.contractAddress
  // );
  // console.log(
  //   "2. Test the deployment by creating a collection through the admin panel"
  // );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
