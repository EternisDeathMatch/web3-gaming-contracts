import { ethers } from "ethers";
import GameMarketplaceV3Artifact from "./GameMarketplaceV3.json";
import IncentiveEngineArtifact from "./IncentiveEngine.json";
import { showError, showSuccess } from "./ui";

// scope = bytes32(uint160(collection))
const zeroPad32 = (addr: string) => ethers.zeroPadValue(addr as `0x${string}`, 32);

export async function wireIncentives({
  marketplaceProxy,
  engineAddr,
  collectionAddr,
  poolBps,              // e.g., 2000 => 20%
  treasuryAddr,
  out
}: {
  marketplaceProxy: string;
  engineAddr: string;
  collectionAddr: string;
  poolBps: number;
  treasuryAddr: string;
  out: HTMLElement;
}) {
  try {
    out.textContent = "🔗 Connecting to MetaMask...";
    await (window as any).ethereum.request({ method: "eth_requestAccounts" });
    const provider = new ethers.BrowserProvider((window as any).ethereum);
    const signer = await provider.getSigner();

    // basic checks
    for (const a of [marketplaceProxy, engineAddr, collectionAddr, treasuryAddr]) {
      if (!/^0x[a-fA-F0-9]{40}$/.test(a)) {
        showError(out, `Invalid address: ${a}`);
        return;
      }
    }
    if (poolBps < 0 || poolBps > 10_000) {
      showError(out, "poolBps must be 0..10000");
      return;
    }

    // set incentive engine + pool on marketplace
    const market = new ethers.Contract(marketplaceProxy, GameMarketplaceV3Artifact.abi, signer);

    out.textContent += "\n⚙️ setIncentiveEngine...";
    let tx = await market.setIncentiveEngine(engineAddr);
    await tx.wait();

    out.textContent += `\n⚙️ setPoolBps(${collectionAddr}, ${poolBps})...`;
    tx = await market.setPoolBps(collectionAddr, poolBps);
    await tx.wait();

    // configure split on engine (NO cashback)
    const engine = new ethers.Contract(engineAddr, IncentiveEngineArtifact.abi, signer);
    const scope = zeroPad32(collectionAddr);

    const split = {
      buyerCashbackBps: 0,
      l1ReferrerBps: 9500,      // 95% of pool
      l2ReferrerBps: 500,       // 5% of pool
      payoutToken: ethers.ZeroAddress, // native
      treasury: treasuryAddr,
      recycleMissingToBuyer: false,
      active: true
    };

    out.textContent += "\n⚙️ setSplit(scope, split)...";
    tx = await engine.setSplit(scope, split);
    await tx.wait();

    showSuccess(out, "\n✅ Incentives wired! Marketplace will now forward pool to engine.");
  } catch (err: any) {
    showError(out, `❌ Wiring failed: ${err?.message || err}`);
  }
}
