import { ethers } from "ethers";
import GameMarketplaceArtifact from "./GameMarketplace.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";
import { showError, showSuccess } from "./ui";

export async function deployMarketplace({
  feeEth,
  feeRecipient,
  asProxy,
  out,
  copyBtn,
}: {
  feeEth: string,
  feeRecipient: string,
  asProxy: boolean,
  out: HTMLElement,
  copyBtn: HTMLButtonElement,
}) {
  try {
    out.textContent = "Deploying GameMarketplace...";
    copyBtn.style.display = "none";

    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const implAbi = GameMarketplaceArtifact.abi;
    const implBytecode = GameMarketplaceArtifact.bytecode;
    const proxyAbi = ERC1967ProxyArtifact.abi;
    const proxyBytecode = ERC1967ProxyArtifact.bytecode;

    if (asProxy) {
      // Deploy implementation
      const implFactory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const implementation = await implFactory.deploy();
      await implementation.waitForDeployment();
      const implAddress = implementation.target;

      // Encode initializer: MUST match your contract!
      const iface = new ethers.Interface(["function initialize(address)"]);
      const initData = iface.encodeFunctionData("initialize", [feeRecipient]);

      // Deploy proxy (NO value sent!)
      const proxyFactory = new ethers.ContractFactory(proxyAbi, proxyBytecode, signer);
      const proxy = await proxyFactory.deploy(implAddress, initData);
      await proxy.waitForDeployment();
      const proxyAddress = proxy.target;

      showSuccess(out, `\nDeployed to: ${proxyAddress}`);
      out.textContent += `\nImplementation: ${implAddress}`;
      (window as any).marketplaceDeployedAddress = proxyAddress;
      copyBtn.style.display = "inline-block";
    } else {
      // Deploy non-proxy with feeRecipient
      const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const contract = await factory.deploy(feeRecipient, {
        value: ethers.parseEther(feeEth || "0"),
      });
      await contract.waitForDeployment();
      const contractAddress = contract.target;

      showSuccess(out, `\nDeployed to: ${contractAddress}`);
      (window as any).marketplaceDeployedAddress = contractAddress;
      copyBtn.style.display = "inline-block";
    }
  } catch (err: any) {
    showError(out, `Error: ${err.message || err}`);
  }
}
