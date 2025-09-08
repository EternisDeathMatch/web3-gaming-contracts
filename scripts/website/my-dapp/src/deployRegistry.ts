import { ethers } from "ethers";
import ReferralRegistryArtifact from "./ReferralRegistry.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";
import { showError, showSuccess } from "./ui";

export async function deployRegistry({
  asProxy,
  out,
  copyBtn,
}: {
  asProxy: boolean;
  out: HTMLElement;
  copyBtn: HTMLButtonElement;
}) {
  try {
    out.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();

    const implAbi = ReferralRegistryArtifact.abi;
    const implBytecode = ReferralRegistryArtifact.bytecode;
    const proxyAbi = ERC1967ProxyArtifact.abi;
    const proxyBytecode = ERC1967ProxyArtifact.bytecode;

    copyBtn.style.display = "none";

    if (asProxy) {
      out.textContent += "\n🚧 Deploying ReferralRegistry implementation...";
      const implFactory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const implementation = await implFactory.deploy();
      await implementation.waitForDeployment();

      // initializer: initialize(address admin)
      const iface = new ethers.Interface(["function initialize(address)"]);
      const admin = await signer.getAddress();
      const initData = iface.encodeFunctionData("initialize", [admin]);

      out.textContent += "\n🚧 Deploying ERC1967Proxy...";
      const proxyFactory = new ethers.ContractFactory(proxyAbi, proxyBytecode, signer);
      const proxy = await proxyFactory.deploy(implementation.target, initData);
      await proxy.waitForDeployment();

      showSuccess(out, `✅ ReferralRegistry proxy: <b>${proxy.target}</b>`);
      out.innerHTML += `<br>Implementation: <b>${implementation.target}</b>`;
      (window as any).registryDeployedAddress = proxy.target;
      copyBtn.style.display = "inline-block";
    } else {
      out.textContent += "\n🚧 Deploying non-upgradeable ReferralRegistry...";
      const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const admin = await signer.getAddress();
      const contract = await factory.deploy();
      await contract.waitForDeployment();
      // call initialize(admin)
      const reg = new ethers.Contract(contract.target, implAbi, signer);
      const tx = await reg.initialize(admin);
      await tx.wait();

      showSuccess(out, `✅ ReferralRegistry: <b>${contract.target}</b>`);
      (window as any).registryDeployedAddress = contract.target;
      copyBtn.style.display = "inline-block";
    }
  } catch (err: any) {
    showError(out, `❌ Deploy failed: ${err?.message || err}`);
  }
}
