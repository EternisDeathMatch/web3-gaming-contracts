import { ethers } from "ethers";
import { showError, showSuccess } from "./ui";

export async function upgradeContract({
  proxyAddr,
  contractType,
  initFnName,
  initFnArgsRaw,
  upgradeOutput
}: {
  proxyAddr: string;
  contractType: string;
  initFnName: string;
  initFnArgsRaw: string;
  upgradeOutput: HTMLElement;
}) {
  try {
    upgradeOutput.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();

    let contractArtifact: any;
    try {
      contractArtifact = await import(/* @vite-ignore */ `./${contractType}.json`);
    } catch (err) {
      showError(upgradeOutput, `Could not find ABI/bytecode for "${contractType}". Check your build artifacts.`);
      return;
    }
    const implAbi = contractArtifact.abi;
    const implBytecode = contractArtifact.bytecode;

    upgradeOutput.textContent += "\n🚧 Deploying new implementation contract...";
    const implFactory = new ethers.ContractFactory(implAbi, implBytecode, signer);
    const implementation = await implFactory.deploy();
    upgradeOutput.textContent += `\nImplementation tx: ${implementation.deploymentTransaction()?.hash}`;
    await implementation.waitForDeployment();
    const newImplAddress = implementation.target;
    upgradeOutput.textContent += `\nImplementation deployed at: ${newImplAddress}`;

    // Prepare callData (encoded function call, or 0x)
    let callData = "0x";
    if (initFnName) {
      try {
        const fnArgs = initFnArgsRaw
          ? (initFnArgsRaw
              .split(",")
              .map((s: string) => s.trim())
              .filter((v: string) => v.length > 0))
          : [];
        const contractInterface = new ethers.Interface(implAbi);
        callData = contractInterface.encodeFunctionData(initFnName, fnArgs);
      } catch (e: any) {
        showError(upgradeOutput, `Error encoding initializer call: ${e.message}`);
        return;
      }
    }

    const proxyContract = new ethers.Contract(
      proxyAddr,
      [
        "function upgradeTo(address newImplementation)",
        "function upgradeToAndCall(address newImplementation, bytes data)"
      ],
      signer
    );

    upgradeOutput.textContent += "\n🚧 Sending upgrade transaction to proxy...";
    let tx;
    if (callData === "0x") {
      tx = await proxyContract.upgradeTo(newImplAddress);
      upgradeOutput.textContent += `\nTx sent: ${tx.hash}`;
      await tx.wait();
      showSuccess(upgradeOutput, "✅ Proxy upgraded (no initializer called)!");
    } else {
      tx = await proxyContract.upgradeToAndCall(newImplAddress, callData);
      upgradeOutput.textContent += `\nTx sent: ${tx.hash}`;
      await tx.wait();
      showSuccess(upgradeOutput, "✅ Proxy upgraded and initialized!");
    }
  } catch (err: any) {
    showError(upgradeOutput, "❌ Upgrade failed:\n" + (err && err.message ? err.message : err));
  }
}
