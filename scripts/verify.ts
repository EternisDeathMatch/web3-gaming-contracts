import { run } from "hardhat";

async function main(): Promise<void> {
  const [,, contractAddress, deploymentFee, feeRecipient] = process.argv;

  if (!contractAddress || !deploymentFee || !feeRecipient) {
    console.error(
      "Usage: npx hardhat run scripts/verify.ts --network <network> <contractAddress> <deploymentFee> <feeRecipient>"
    );
    process.exit(1);
  }

  console.log("Verifying contract at:", contractAddress);

  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: [deploymentFee, feeRecipient],
    });
    console.log("Contract verified successfully!");
  } catch (error: any) {
    console.error("Verification failed:", error.message || error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
