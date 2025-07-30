import { ethers } from "ethers";
import { showError, showSuccess } from "./ui.ts";

export async function getImplementationAddress(proxyAddr: string, currentImplResult: HTMLElement) {
  try {
    if (!(window as any).ethereum) throw new Error("MetaMask required");
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const implStorageSlot =
      "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
    let implAddr = await provider.getStorage(proxyAddr, implStorageSlot);
    implAddr = "0x" + implAddr.slice(-40);
    currentImplResult.textContent = `Implementation: ${implAddr}`;
  } catch (e: any) {
    showError(currentImplResult, e.message);
  }
}

export async function callProxyFunction({ 
  proxyAddr,
  fnSig,
  fnArgs,
  isWrite,
  fnResult
}: {
  proxyAddr: string;
  fnSig: string;
  fnArgs: string[];
  isWrite: boolean;
  fnResult: HTMLElement;
}) {
  try {
    if (!(window as any).ethereum) throw new Error("MetaMask required");
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);

    const iface = new ethers.Interface([`function ${fnSig}`]);
    const fnName = fnSig.split("(")[0];

    if (isWrite) {
      const signer = await provider.getSigner();
      const contract = new ethers.Contract(proxyAddr, iface.fragments, signer);
      const tx = await contract[fnName](...fnArgs);
      showSuccess(fnResult, `Tx sent: ${tx.hash}`);
      await tx.wait();
      showSuccess(fnResult, "✅ Transaction confirmed!");
    } else {
      const contract = new ethers.Contract(proxyAddr, iface.fragments, provider);
      const result = await contract[fnName](...fnArgs);
      showSuccess(fnResult, JSON.stringify(result));
    }
  } catch (e: any) {
    showError(fnResult, e.message);
  }
}
