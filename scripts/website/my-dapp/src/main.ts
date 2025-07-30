import { ethers } from "ethers";
import CollectionFactoryArtifact from "./CollectionFactory.json";
import ERC1967ProxyArtifact from "./ERC1967Proxy.json";

// --- DEPLOY SECTION ---
const implAbi = CollectionFactoryArtifact.abi;
const implBytecode = CollectionFactoryArtifact.bytecode;
const proxyAbi = ERC1967ProxyArtifact.abi;
const proxyBytecode = ERC1967ProxyArtifact.bytecode;

const out = document.getElementById("output") as HTMLElement;
const deployBtn = document.getElementById("deployBtn") as HTMLButtonElement;
const copyBtn = document.getElementById("copyBtn") as HTMLButtonElement;
const feeInput = document.getElementById("deploymentFee") as HTMLInputElement;
const recipientInput = document.getElementById(
  "feeRecipient"
) as HTMLInputElement;
const proxyToggle = document.getElementById("deployProxy") as HTMLInputElement;

async function autofillFeeRecipient() {
  if ((window as any).ethereum) {
    try {
      await (window as any).ethereum.request({ method: "eth_requestAccounts" });
      const provider = new ethers.BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      recipientInput.value = await signer.getAddress();
    } catch {}
  }
}
autofillFeeRecipient();

deployBtn.onclick = async function () {
  out.textContent = "";
  deployBtn.disabled = true;
  copyBtn.style.display = "none";

  const feeEth = feeInput.value.trim();
  const feeRecipient = recipientInput.value.trim();
  const asProxy = proxyToggle.checked;

  if (!feeEth || isNaN(Number(feeEth)) || Number(feeEth) < 0) {
    out.innerHTML =
      '<span class="error">Deployment fee must be a valid number (0 or more)</span>';
    deployBtn.disabled = false;
    return;
  }
  if (!/^0x[a-fA-F0-9]{40}$/.test(feeRecipient)) {
    out.innerHTML =
      '<span class="error">Fee recipient must be a valid Ethereum address</span>';
    deployBtn.disabled = false;
    return;
  }
  if (!(window as any).ethereum) {
    out.innerHTML =
      '<span class="error">MetaMask not found! Please install and unlock it in this browser.</span>';
    deployBtn.disabled = false;
    return;
  }

  try {
    out.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();
    const feeWei = ethers.parseEther(feeEth);

    if (asProxy) {
      out.textContent += "\n🚧 Deploying implementation (logic contract)...";
      const implFactory = new ethers.ContractFactory(
        implAbi,
        implBytecode,
        signer
      );
      const implementation = await implFactory.deploy();
      out.textContent += `\nImplementation tx: ${
        implementation.deploymentTransaction()?.hash
      }`;
      await implementation.waitForDeployment();
      out.textContent += `\nImplementation deployed at: ${implementation.target}`;

      // Encode initialize() call
      const iface = new ethers.Interface([
        "function initialize(uint256,address)",
      ]);
      const initData = iface.encodeFunctionData("initialize", [
        feeWei,
        feeRecipient,
      ]);

      out.textContent += "\n🚧 Deploying ERC1967Proxy (UUPS proxy)...";
      const proxyFactory = new ethers.ContractFactory(
        proxyAbi,
        proxyBytecode,
        signer
      );
      const proxy = await proxyFactory.deploy(implementation.target, initData);
      out.textContent += `\nProxy tx: ${proxy.deploymentTransaction()?.hash}`;
      out.textContent += `\nWaiting for proxy deployment confirmation...`;
      await proxy.waitForDeployment();

      out.innerHTML += `\n<span class="success">✅ Proxy deployed at: <b id="contractAddress">${proxy.target}</b></span>`;
      out.innerHTML += `<br>Implementation address: <b>${implementation.target}</b>`;
      copyBtn.style.display = "inline-block";
      (window as any).contractDeployedAddress = proxy.target;
      out.innerHTML += `<br><small>You can use this proxy address with your implementation ABI for all contract calls.</small>`;
    } else {
      out.textContent += "\n🚧 Deploying non-upgradeable contract...";
      const factory = new ethers.ContractFactory(implAbi, implBytecode, signer);
      const contract = await factory.deploy(feeWei, feeRecipient);
      out.textContent += `\nTransaction sent: ${
        contract.deploymentTransaction()?.hash
      }`;
      out.textContent += `\nWaiting for deployment confirmation...`;

      await contract.waitForDeployment();
      out.innerHTML += `\n<span class="success">✅ Contract deployed at: <b id="contractAddress">${contract.target}</b></span>`;
      copyBtn.style.display = "inline-block";
      (window as any).contractDeployedAddress = contract.target;
    }
  } catch (err: any) {
    out.innerHTML =
      '<span class="error">❌ Deployment failed:</span>\n' +
      (err && err.message ? err.message : err);
  }
  deployBtn.disabled = false;
};

copyBtn.onclick = function () {
  const addr = (window as any).contractDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copyBtn.innerText = "Copied!";
    setTimeout(() => {
      copyBtn.innerText = "Copy Address";
    }, 1200);
  }
};

// === UPGRADE SECTION ===
const deployAndUpgradeBtn = document.getElementById(
  "deployAndUpgradeBtn"
) as HTMLButtonElement;
const upgradeProxyInput = document.getElementById(
  "upgradeProxyAddress"
) as HTMLInputElement;
const upgradeTypeInput = document.getElementById(
  "upgradeContractType"
) as HTMLInputElement;
const upgradeOutput = document.getElementById("upgradeOutput") as HTMLElement;

deployAndUpgradeBtn.onclick = async function () {
  upgradeOutput.textContent = "";
  deployAndUpgradeBtn.disabled = true;

  const proxyAddr = upgradeProxyInput.value.trim();
  const contractType = upgradeTypeInput.value.trim() || "CollectionFactory";

  if (!/^0x[a-fA-F0-9]{40}$/.test(proxyAddr)) {
    upgradeOutput.innerHTML =
      '<span class="error">Proxy address invalid.</span>';
    deployAndUpgradeBtn.disabled = false;
    return;
  }

  try {
    upgradeOutput.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();

    // Dynamically load artifact based on contract name
    let contractArtifact: any;
    try {
      contractArtifact = await import(
        /* @vite-ignore */ `./${contractType}.json`
      );
    } catch (err) {
      upgradeOutput.innerHTML = `<span class="error">Could not find ABI/bytecode for "${contractType}". Check your build artifacts.</span>`;
      deployAndUpgradeBtn.disabled = false;
      return;
    }

    const implAbi = contractArtifact.abi;
    const implBytecode = contractArtifact.bytecode;

    upgradeOutput.textContent +=
      "\n🚧 Deploying new implementation contract...";
    const implFactory = new ethers.ContractFactory(
      implAbi,
      implBytecode,
      signer
    );
    const implementation = await implFactory.deploy();
    upgradeOutput.textContent += `\nImplementation tx: ${
      implementation.deploymentTransaction()?.hash
    }`;
    await implementation.waitForDeployment();
    const newImplAddress = implementation.target;
    upgradeOutput.textContent += `\nImplementation deployed at: ${newImplAddress}`;

    // --- UI Initializer fields ---
    const initFnNameInput = document.getElementById("initFnName") as HTMLInputElement | null;
    const initFnArgsInput = document.getElementById("initFnArgs") as HTMLInputElement | null;

    if (!initFnNameInput || !initFnArgsInput) {
      upgradeOutput.innerHTML += `<span class="error">Initializer fields not found in the DOM.</span>`;
      deployAndUpgradeBtn.disabled = false;
      return;
    }

    const initFnName = initFnNameInput.value.trim();
    const initFnArgsRaw = initFnArgsInput.value.trim();

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
        upgradeOutput.innerHTML += `<span class="error">Error encoding initializer call: ${e.message}</span>`;
        deployAndUpgradeBtn.disabled = false;
        return;
      }
    }

    // Get interface for upgradeTo/upgradeToAndCall
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
      // No initializer, just upgradeTo
      tx = await proxyContract.upgradeTo(newImplAddress);
      upgradeOutput.textContent += `\nTx sent: ${tx.hash}`;
      await tx.wait();
      upgradeOutput.innerHTML += `\n<span class="success">✅ Proxy upgraded (no initializer called)!</span>`;
    } else {
      // With initializer
      tx = await proxyContract.upgradeToAndCall(newImplAddress, callData);
      upgradeOutput.textContent += `\nTx sent: ${tx.hash}`;
      await tx.wait();
      upgradeOutput.innerHTML += `\n<span class="success">✅ Proxy upgraded and initialized!</span>`;
    }
  } catch (err: any) {
    upgradeOutput.innerHTML =
      '<span class="error">❌ Upgrade failed:</span>\n' +
      (err && err.message ? err.message : err);
  }
  deployAndUpgradeBtn.disabled = false;
};

// === TEST PROXY SECTION ===
const getImplBtn = document.getElementById("getImplBtn") as HTMLButtonElement;
const testProxyInput = document.getElementById( 
  "testProxyAddress"
) as HTMLInputElement;
const currentImplResult = document.getElementById(
  "currentImplResult"
) as HTMLElement;

getImplBtn.onclick = async function () {
  currentImplResult.textContent = "";
  const proxyAddr = testProxyInput.value.trim();
  if (!/^0x[a-fA-F0-9]{40}$/.test(proxyAddr)) {
    currentImplResult.innerHTML = "Invalid proxy address.";
    return;
  }
  try {
    if (!(window as any).ethereum) throw new Error("MetaMask required");
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    // ERC1967 implementation slot (keccak-256("eip1967.proxy.implementation") - 1)
    const implStorageSlot =
      "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
    let implAddr = await provider.getStorage(proxyAddr, implStorageSlot);
    // Ethers returns 32-byte hex, so right-pad, strip to last 40 chars, and 0x prefix
    implAddr = "0x" + implAddr.slice(-40);
    currentImplResult.textContent = `Implementation: ${implAddr}`;
  } catch (e: any) {
    currentImplResult.innerHTML = `<span class="error">${e.message}</span>`;
  }
};

const callFnBtn = document.getElementById("callFnBtn") as HTMLButtonElement;
const fnSignatureInput = document.getElementById(
  "fnSignature"
) as HTMLInputElement;
const fnArgsInput = document.getElementById("fnArgs") as HTMLInputElement;
const fnResult = document.getElementById("fnResult") as HTMLElement;
const isWriteTx = document.getElementById("isWriteTx") as HTMLInputElement;

callFnBtn.onclick = async function () {
  fnResult.textContent = "";
  const proxyAddr = testProxyInput.value.trim();
  const fnSig = fnSignatureInput.value.trim();
  const fnArgs = fnArgsInput.value.trim()
    ? fnArgsInput.value.trim().split(",")
    : [];
  if (!/^0x[a-fA-F0-9]{40}$/.test(proxyAddr)) {
    fnResult.innerHTML = "Invalid proxy address.";
    return;
  }
  if (!fnSig) {
    fnResult.innerHTML = "Function signature required.";
    return;
  }
  try {
    if (!(window as any).ethereum) throw new Error("MetaMask required");
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);

    const iface = new ethers.Interface([`function ${fnSig}`]);
    const fnName = fnSig.split("(")[0];

    if (isWriteTx.checked) {
      // WRITE: use signer
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(proxyAddr, iface.fragments, signer);
      const tx = await contract[fnName](...fnArgs);
      fnResult.innerHTML = `<span class="success">Tx sent: ${tx.hash}</span>`;
      await tx.wait();
      fnResult.innerHTML += `<br><span class="success">✅ Transaction confirmed!</span>`;
    } else {
      // READ: use provider (NOT signer!)
      const contract = new ethers.Contract(
        proxyAddr,
        iface.fragments,
        provider
      );
      const result = await contract[fnName](...fnArgs);
      fnResult.innerHTML = `<span class="success">${JSON.stringify(
        result
      )}</span>`;
    }
  } catch (e: any) {
    fnResult.innerHTML = `<span class="error">${e.message}</span>`;
  }
};
