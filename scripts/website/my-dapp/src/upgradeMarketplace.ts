import { ethers } from "ethers";
import GameMarketplaceArtifact from "./GameMarketplaceV3.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";
import { showError, showSuccess } from "./ui";

export async function upgradeMarketplace({
  proxyAddr,
  contractType = "GameMarketplaceV3",
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

    // Check ABI and bytecode
    const implAbi = GameMarketplaceArtifact.abi;
    const implBytecode = GameMarketplaceArtifact.bytecode;
    const proxyAbi = ERC1967ProxyArtifact.abi;

    console.log("🔍 Contract Type:", contractType);
    console.log("🔍 ABI length:", implAbi.length);
    console.log("🔍 ABI contains version():", implAbi.some((f: any) => f.name === "version"));
    console.log("🔍 Bytecode size:", implBytecode.length);
    console.log("🔍 Proxy Address:", proxyAddr);

    // Deploy new implementation
    const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
    const newImpl = await factory.deploy();
    await newImpl.waitForDeployment();
    const implAddress = await newImpl.getAddress();

    console.log("✅ Deployed new implementation at:", implAddress);

    // Try to call version() immediately on the new impl
    try {
      const tmp = new ethers.Contract(implAddress, implAbi, signer);
      const v = await tmp.version();
      console.log("✅ Impl.version():", v);
    } catch (err: any) {
      console.error("⚠️ version() call on new impl failed:", err.message || err);
    }

    // Encode initializer (if provided)
    let data = "0x";
    if (initFnName) {
      const iface = new ethers.Interface(implAbi);
      const args = (initFnArgsRaw ?? "")
        .split(",")
        .map((a) => a.trim())
        .filter((a) => a !== "");
      data = iface.encodeFunctionData(initFnName, args);
      console.log(`🔍 Encoded initializer: ${initFnName}(${args.join(",")}) -> ${data}`);
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
    console.log("⏳ Sent upgrade tx:", tx.hash);

    await tx.wait();
    console.log("🎉 Upgrade confirmed! Proxy now points to:", implAddress);

    showSuccess(upgradeOutput, `\nUpgraded proxy! New impl: ${implAddress}`);
  } catch (err: any) {
    console.error("❌ Upgrade failed:", err);
    showError(upgradeOutput, `Error: ${err.message || err}`);
  }
}
