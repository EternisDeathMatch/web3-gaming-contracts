import { ethers } from "ethers";
import SenderArtifact from "./NFTBatchSender.json";
import { showError, showSuccess } from "./ui";

type DeployArgs = {
  maxBatch: string | number;          // e.g. "100"
  initialOwner?: `0x${string}`;       // optional if your ctor uses msg.sender
  out: HTMLElement;
  copyBtn: HTMLButtonElement;
};

export async function deployBatchSender({ maxBatch, initialOwner, out, copyBtn }: DeployArgs) {
  try {
    out.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });

    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();

    // OPTIONAL: make sure user is on XDC (50) or Apothem (51)
    await ensureChain(provider, out);

    out.textContent += "\n🚧 Deploying NFTBatchSender...";
    const factory = new ethers.ContractFactory(SenderArtifact.abi, SenderArtifact.bytecode, signer);

    // Build args based on your constructor
    const args = initialOwner
      ? [BigInt(maxBatch as any), initialOwner]
      : [BigInt(maxBatch as any)];

    const contract = await factory.deploy(...args);
    out.textContent += `\nTx: ${contract.deploymentTransaction()?.hash}`;
    out.textContent += `\nWaiting for confirmation...`;
    await contract.waitForDeployment();

    const addr = contract.target as `0x${string}`;
    showSuccess(out, `✅ NFTBatchSender deployed at: <b id="batchSenderAddr">${addr}</b>`);
    (window as any).batchSenderDeployedAddress = addr;
    copyBtn.style.display = "inline-block";
  } catch (err: any) {
    showError(out, "❌ Deploy failed:" + (err?.message ? "\n" + err.message : ""));
  }
}

async function ensureChain(provider: ethers.BrowserProvider, out: HTMLElement) {
  const net = await provider.getNetwork();
  const chainId = Number(net.chainId);
  if (chainId !== 50 && chainId !== 51) {
    out.textContent += `\n⚠️ Wrong chain (${chainId}). Please switch to XDC (50) or Apothem (51).`;
    // If you want, trigger a request to switch/add here.
  }
}
