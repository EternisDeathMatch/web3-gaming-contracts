import { ethers } from "ethers";
import GameMarketplaceArtifact from "./GameMarketplace.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";
import { showError, showSuccess } from "./ui";

export async function upgradeMarketplace({
  proxyAddr,
  contractType = "GameMarketplace",
  initFnName,
  initFnArgsRaw,
  upgradeOutput,
}: {
  proxyAddr: string,
  contractType?: string, // not used here, placeholder for multi-version
  initFnName?: string,
  initFnArgsRaw?: string,
  upgradeOutput: HTMLElement,
}) {
  try {
    upgradeOutput.textContent = "Deploying new implementation...";
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    const implAbi = GameMarketplaceArtifact.abi;
    const implBytecode = GameMarketplaceArtifact.bytecode;
    const proxyAbi = ERC1967ProxyArtifact.abi;

    // Deploy new implementation
    const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
    const newImpl = await factory.deploy();
    await newImpl.waitForDeployment();
    const implAddress = await newImpl.getAddress();

    // Encode initializer (if provided)
    let data = "0x";
    if (initFnName) {
      const iface = new ethers.Interface(implAbi);
      const args = (initFnArgsRaw ?? "").split(",").map(a => a.trim()).filter(a => a !== "");
      data = iface.encodeFunctionData(initFnName, args);
    }

    // Upgrade
    const proxy = new ethers.Contract(proxyAddr, proxyAbi, signer);
    let tx;
    if (initFnName && data !== "0x") {
      tx = await proxy.upgradeToAndCall(implAddress, data);
    } else {
      tx = await proxy.upgradeTo(implAddress);
    }
    upgradeOutput.textContent += `\nTx: ${tx.hash}`;
    await tx.wait();
    showSuccess(upgradeOutput, `\nUpgraded proxy! New impl: ${implAddress}`);
  } catch (err: any) {
    showError(upgradeOutput, `Error: ${err.message || err}`);
  }
}
