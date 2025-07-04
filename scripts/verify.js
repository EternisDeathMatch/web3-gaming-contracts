
const hre = require("hardhat");

async function main() {
  const contractAddress = process.argv[2];
  const deploymentFee = process.argv[3];
  const feeRecipient = process.argv[4];

  if (!contractAddress || !deploymentFee || !feeRecipient) {
    console.log("Usage: npx hardhat run scripts/verify.js --network <network> <contractAddress> <deploymentFee> <feeRecipient>");
    process.exit(1);
  }

  console.log("Verifying contract at:", contractAddress);

  try {
    await hre.run("verify:verify", {
      address: contractAddress,
      constructorArguments: [deploymentFee, feeRecipient],
    });
    console.log("Contract verified successfully!");
  } catch (error) {
    console.log("Verification failed:", error.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
