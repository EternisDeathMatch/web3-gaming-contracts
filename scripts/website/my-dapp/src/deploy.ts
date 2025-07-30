import { ethers } from "ethers";
import CollectionFactoryArtifact from "./CollectionFactory.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";
import { showError, showSuccess } from "./ui.ts";

const implAbi = CollectionFactoryArtifact.abi;
const implBytecode = CollectionFactoryArtifact.bytecode;
const proxyAbi = ERC1967ProxyArtifact.abi;
const proxyBytecode = ERC1967ProxyArtifact.bytecode;

export async function deployContract({
  feeEth,
  feeRecipient,
  asProxy,
  out,
  copyBtn
}: {
  feeEth: string;
  feeRecipient: string;
  asProxy: boolean;
  out: HTMLElement;
  copyBtn: HTMLButtonElement;
}) {
  try {
    out.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();
    const feeWei = ethers.parseEther(feeEth);

    if (asProxy) {
      out.textContent += "\n🚧 Deploying implementation (logic contract)...";
      const implFactory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const implementation = await implFactory.deploy();
      out.textContent += `\nImplementation tx: ${implementation.deploymentTransaction()?.hash}`;
      await implementation.waitForDeployment();
      out.textContent += `\nImplementation deployed at: ${implementation.target}`;

      const iface = new ethers.Interface(["function initialize(uint256,address)"]);
      const initData = iface.encodeFunctionData("initialize", [feeWei, feeRecipient]);

      out.textContent += "\n🚧 Deploying ERC1967Proxy (UUPS proxy)...";
      const proxyFactory = new ethers.ContractFactory(proxyAbi, proxyBytecode, signer);
      const proxy = await proxyFactory.deploy(implementation.target, initData);
      out.textContent += `\nProxy tx: ${proxy.deploymentTransaction()?.hash}`;
      out.textContent += `\nWaiting for proxy deployment confirmation...`;
      await proxy.waitForDeployment();

      showSuccess(out, `✅ Proxy deployed at: <b id="contractAddress">${proxy.target}</b>`);
      out.innerHTML += `<br>Implementation address: <b>${implementation.target}</b>`;
      copyBtn.style.display = "inline-block";
      (window as any).contractDeployedAddress = proxy.target;
      out.innerHTML += `<br><small>You can use this proxy address with your implementation ABI for all contract calls.</small>`;
    } else {
      out.textContent += "\n🚧 Deploying non-upgradeable contract...";
      const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const contract = await factory.deploy(feeWei, feeRecipient);
      out.textContent += `\nTransaction sent: ${contract.deploymentTransaction()?.hash}`;
      out.textContent += `\nWaiting for deployment confirmation...`;
      await contract.waitForDeployment();

      showSuccess(out, `✅ Contract deployed at: <b id="contractAddress">${contract.target}</b>`);
      copyBtn.style.display = "inline-block";
      (window as any).contractDeployedAddress = contract.target;
    }
  } catch (err: any) {
    showError(out, "❌ Deployment failed:" + (err && err.message ? "\n" + err.message : ""));
  }
}
