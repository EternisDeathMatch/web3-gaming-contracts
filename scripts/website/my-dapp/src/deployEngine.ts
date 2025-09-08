import { ethers } from "ethers";
import IncentiveEngineArtifact from "./IncentiveEngine.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";
import { showError, showSuccess } from "./ui";

export async function deployEngine({
  registryAddr,
  asProxy,
  out,
  copyBtn,
}: {
  registryAddr: string;
  asProxy: boolean;
  out: HTMLElement;
  copyBtn: HTMLButtonElement;
}) {
  try {
    out.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();

    if (!/^0x[a-fA-F0-9]{40}$/.test(registryAddr)) {
      showError(out, "Registry address invalid.");
      return;
    }

    const implAbi = IncentiveEngineArtifact.abi;
    const implBytecode = IncentiveEngineArtifact.bytecode;
    const proxyAbi = ERC1967ProxyArtifact.abi;
    const proxyBytecode = ERC1967ProxyArtifact.bytecode;

    copyBtn.style.display = "none";

    if (asProxy) {
      // deploy implementation
      const implFactory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const implementation = await implFactory.deploy();
      await implementation.waitForDeployment();

      // initializer: initialize(address admin, address registry)
      const iface = new ethers.Interface(["function initialize(address,address)"]);
      const admin = await signer.getAddress();
      const initData = iface.encodeFunctionData("initialize", [admin, registryAddr]);

      const proxyFactory = new ethers.ContractFactory(proxyAbi, proxyBytecode, signer);
      const proxy = await proxyFactory.deploy(implementation.target, initData);
      await proxy.waitForDeployment();

      showSuccess(out, `✅ IncentiveEngine proxy: <b>${proxy.target}</b>`);
      out.innerHTML += `<br>Implementation: <b>${implementation.target}</b>`;
      (window as any).engineDeployedAddress = proxy.target;
      copyBtn.style.display = "inline-block";
    } else {
      // non-upgradeable: deploy + call initialize(...)
      const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const contract = await factory.deploy();
      await contract.waitForDeployment();

      const admin = await signer.getAddress();
      const engine = new ethers.Contract(contract.target, implAbi, signer);
      const tx = await engine.initialize(admin, registryAddr);
      await tx.wait();

      showSuccess(out, `✅ IncentiveEngine: <b>${contract.target}</b>`);
      (window as any).engineDeployedAddress = contract.target;
      copyBtn.style.display = "inline-block";
    }
  } catch (err: any) {
    showError(out, `❌ Deploy failed: ${err?.message || err}`);
  }
}
