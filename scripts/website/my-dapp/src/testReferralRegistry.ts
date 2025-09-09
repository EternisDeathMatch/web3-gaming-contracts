import { ethers } from "ethers";
import { showError } from "./ui";
// If your build outputs ReferralRegistry.json, this import will work.
// If not, the code will fall back to fnSig-only mode automatically.
import ReferralRegistryArtifact from "./ReferralRegistry.json";

// ERC1967 implementation slot
const ERC1967_IMPL_SLOT =
  "0x360894A13BA1A3210667C828492DB98DCA3E2076CC3735A920A3CA505D382BBC";

export async function getRegistryImplAddress(proxyAddr: string, out: HTMLElement) {
  try {
    out.textContent = "Reading implementation address...";
    const provider = new ethers.BrowserProvider(window.ethereum);
    const implRaw = await provider.getStorage(proxyAddr, ERC1967_IMPL_SLOT);
    const impl = ethers.getAddress("0x" + implRaw.slice(-40));
    out.textContent = `Implementation: ${impl}`;
    return impl;
  } catch (err: any) {
    showError(out, `Error: ${err.message || err}`);
    return null;
  }
}

export async function callRegistryFn({
  proxyAddr,
  fnSig,
  fnArgs,
  isWrite,
  fnResult,
}: {
  proxyAddr: string;
  fnSig: string;   // e.g. "bindReferrer(address)" or "referrerOf(address)"
  fnArgs: any[];   // e.g. ["0xabc..."]
  isWrite: boolean;
  fnResult: HTMLElement;
}) {
  try {
    const provider = new ethers.BrowserProvider(window.ethereum);
    const signer = await provider.getSigner();

    const fnName = fnSig.split("(")[0].trim();

    // Prefer ABI if available; otherwise construct from fnSig
    let abi = (ReferralRegistryArtifact as any)?.abi ?? [];
    let useAbi = false;
    try {
      const tmp = new ethers.Interface(abi);
      // Throws if function name not in ABI
      tmp.getFunction(fnName);
      useAbi = true;
    } catch {
      useAbi = false;
    }

    const iface = useAbi
      ? new ethers.Interface(abi)
      : new ethers.Interface([`function ${fnSig}`]);

    const contract = new ethers.Contract(proxyAddr, iface.fragments, signer);

    if (isWrite) {
      const tx = await (contract as any)[fnName](...fnArgs);
      fnResult.textContent = `Tx: ${tx.hash}`;
      await tx.wait();
      fnResult.textContent += `\nConfirmed!`;
    } else {
      const result = await (contract as any)[fnName](...fnArgs);
      fnResult.textContent = `Result: ${JSON.stringify(
        result,
        (_k, v) => (typeof v === "bigint" ? v.toString() : v)
      )}`;
    }
  } catch (err: any) {
    showError(fnResult, `Error: ${err.message || err}`);
  }
}
