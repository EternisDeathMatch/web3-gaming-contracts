import { ethers } from "ethers";
import GameMarketplaceArtifact from "./GameMarketplace.json";
import { showError } from "./ui";

// Get implementation address of a proxy
export async function getMarketplaceImplAddress(
  proxyAddr: string,
  out: HTMLElement
) {
  try {
    out.textContent = "Reading implementation address...";
    // ERC1967 implementation slot
    const provider = new ethers.BrowserProvider(window.ethereum);
    const implSlot =
      "0x360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC";
    const implAddr = await provider.getStorage(proxyAddr, implSlot);
    const result = ethers.getAddress("0x" + implAddr.slice(-40));
    out.textContent = `Implementation: ${result}`;
    return result;
  } catch (err: any) {
    showError(out, `Error: ${err.message || err}`);
    return null;
  }
}

// Call any function on proxy
export async function callMarketplaceFn({
  proxyAddr,
  fnSig,
  fnArgs,
  isWrite,
  fnResult,
}: {
  proxyAddr: string;
  fnSig: string;
  fnArgs: any[];
  isWrite: boolean;
  fnResult: HTMLElement;
}) {
  try {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();
    const iface = new ethers.Interface(GameMarketplaceArtifact.abi);
    const fnName = fnSig.split("(")[0];
    const contract = new ethers.Contract(
      proxyAddr,
      GameMarketplaceArtifact.abi,
      signer
    );

    if (isWrite) {
      const tx = await contract[fnName](...fnArgs);
      fnResult.textContent = `Tx: ${tx.hash}`;
      await tx.wait();
      fnResult.textContent += `\nConfirmed!`;
    } else {
      const result = await contract[fnName](...fnArgs);
      fnResult.textContent = `Result: ${JSON.stringify(result, (_key, value) =>
        typeof value === "bigint" ? value.toString() : value
      )}`;
    }
  } catch (err: any) {
    showError(fnResult, `Error: ${err.message || err}`);
  }
}
