import { ethers } from "ethers";
import { deployBatchSender } from "./deployBatchSender";
import { deployContract } from "./deploy";
import { upgradeContract } from "./upgrade";
import { getImplementationAddress, callProxyFunction } from "./testProxy";
import { deployMarketplace } from "./deployMarketplace";
import { upgradeMarketplace } from "./upgradeMarketplace";
import {
  getMarketplaceImplAddress,
  callMarketplaceFn,
} from "./testProxyMarketplace";
import { autofillFeeRecipient } from "./ui";
import { deployRegistry } from "./deployRegistry";
import { deployEngine } from "./deployEngine";
import { wireIncentives } from "./wireIncentives";
import { getRegistryImplAddress, callRegistryFn } from "./testReferralRegistry";
import { getEngineImplAddress, callEngineFn } from "./testIncentiveEngine";

declare global {
  interface Window {
    ethereum?: any;
    contractDeployedAddress?: string;
    marketplaceDeployedAddress?: string;
  }
}

// --- CollectionFactory Section ---
const out = document.getElementById("output") as HTMLElement;
const deployBtn = document.getElementById("deployBtn") as HTMLButtonElement;
const copyBtn = document.getElementById("copyBtn") as HTMLButtonElement;
const feeInput = document.getElementById("deploymentFee") as HTMLInputElement;
const recipientInput = document.getElementById(
  "feeRecipient"
) as HTMLInputElement;
const proxyToggle = document.getElementById("deployProxy") as HTMLInputElement;

autofillFeeRecipient(recipientInput);

deployBtn.onclick = async function () {
  await deployContract({
    feeEth: feeInput.value.trim(),
    feeRecipient: recipientInput.value.trim(),
    asProxy: proxyToggle.checked,
    out,
    copyBtn,
  });
};

copyBtn.onclick = function () {
  const addr = window.contractDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copyBtn.innerText = "Copied!";
    setTimeout(() => {
      copyBtn.innerText = "Copy Address";
    }, 1200);
  }
};

// UPGRADE CollectionFactory
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
const initFnNameInput = document.getElementById(
  "initFnName"
) as HTMLInputElement;
const initFnArgsInput = document.getElementById(
  "initFnArgs"
) as HTMLInputElement;

deployAndUpgradeBtn.onclick = async function () {
  await upgradeContract({
    proxyAddr: upgradeProxyInput.value.trim(),
    contractType: upgradeTypeInput.value.trim() || "CollectionFactory",
    initFnName: initFnNameInput.value.trim(),
    initFnArgsRaw: initFnArgsInput.value.trim(),
    upgradeOutput,
  });
};

// TEST PROXY CollectionFactory
const getImplBtn = document.getElementById("getImplBtn") as HTMLButtonElement;
const testProxyInput = document.getElementById(
  "testProxyAddress"
) as HTMLInputElement;
const currentImplResult = document.getElementById(
  "currentImplResult"
) as HTMLElement;

getImplBtn.onclick = async function () {
  await getImplementationAddress(
    testProxyInput.value.trim(),
    currentImplResult
  );
};

const callFnBtn = document.getElementById("callFnBtn") as HTMLButtonElement;
const fnSignatureInput = document.getElementById(
  "fnSignature"
) as HTMLInputElement;
const fnArgsInput = document.getElementById("fnArgs") as HTMLInputElement;
const fnResult = document.getElementById("fnResult") as HTMLElement;
const isWriteTx = document.getElementById("isWriteTx") as HTMLInputElement;

callFnBtn.onclick = async function () {
  await callProxyFunction({
    proxyAddr: testProxyInput.value.trim(),
    fnSig: fnSignatureInput.value.trim(),
    fnArgs: fnArgsInput.value.trim() ? fnArgsInput.value.trim().split(",") : [],
    isWrite: isWriteTx.checked,
    fnResult,
  });
};

// ===========================
// === MARKETPLACE SECTION ===
// ===========================

const deployMarketplaceBtn = document.getElementById(
  "deployMarketplaceBtn"
) as HTMLButtonElement;
const copyMarketplaceBtn = document.getElementById(
  "copyMarketplaceBtn"
) as HTMLButtonElement;
const marketplaceFeeInput = document.getElementById(
  "marketplaceDeploymentFee"
) as HTMLInputElement;
const marketplaceRecipientInput = document.getElementById(
  "marketplaceFeeRecipient"
) as HTMLInputElement;
const marketplaceProxyToggle = document.getElementById(
  "marketplaceDeployProxy"
) as HTMLInputElement;
const deployMarketplaceOutput = document.getElementById(
  "deployMarketplaceOutput"
) as HTMLElement;

// Deploy GameMarketplace (same pattern as CollectionFactory!)
deployMarketplaceBtn.onclick = async function () {
  await deployMarketplace({
    feeEth: marketplaceFeeInput.value.trim(),
    feeRecipient: marketplaceRecipientInput.value.trim(),
    asProxy: marketplaceProxyToggle.checked,
    out: deployMarketplaceOutput,
    copyBtn: copyMarketplaceBtn,
  });
};

copyMarketplaceBtn.onclick = function () {
  const addr = window.marketplaceDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copyMarketplaceBtn.innerText = "Copied!";
    setTimeout(() => {
      copyMarketplaceBtn.innerText = "Copy Address";
    }, 1200);
  }
};

// UPGRADE GameMarketplace (same pattern!)
const deployAndUpgradeMarketplaceBtn = document.getElementById(
  "deployAndUpgradeMarketplaceBtn"
) as HTMLButtonElement;
const upgradeMarketplaceProxyInput = document.getElementById(
  "upgradeMarketplaceProxyAddress"
) as HTMLInputElement;
const upgradeMarketplaceTypeInput = document.getElementById(
  "upgradeMarketplaceContractType"
) as HTMLInputElement;
const upgradeMarketplaceOutput = document.getElementById(
  "upgradeMarketplaceOutput"
) as HTMLElement;
const marketplaceInitFnNameInput = document.getElementById(
  "marketplaceInitFnName"
) as HTMLInputElement;
const marketplaceInitFnArgsInput = document.getElementById(
  "marketplaceInitFnArgs"
) as HTMLInputElement;

deployAndUpgradeMarketplaceBtn.onclick = async function () {
  await upgradeMarketplace({
    proxyAddr: upgradeMarketplaceProxyInput.value.trim(),
    contractType: upgradeMarketplaceTypeInput.value.trim() || "GameMarketplace",
    initFnName: marketplaceInitFnNameInput.value.trim(),
    initFnArgsRaw: marketplaceInitFnArgsInput.value.trim(),
    upgradeOutput: upgradeMarketplaceOutput,
  });
};

// TEST PROXY GameMarketplace (same pattern!)
const getMarketplaceImplBtn = document.getElementById(
  "getMarketplaceImplBtn"
) as HTMLButtonElement;
const testMarketplaceProxyInput = document.getElementById(
  "testMarketplaceProxyAddress"
) as HTMLInputElement;
const marketplaceCurrentImplResult = document.getElementById(
  "marketplaceCurrentImplResult"
) as HTMLElement;

getMarketplaceImplBtn.onclick = async function () {
  await getMarketplaceImplAddress(
    testMarketplaceProxyInput.value.trim(),
    marketplaceCurrentImplResult
  );
};

const callMarketplaceFnBtn = document.getElementById(
  "callMarketplaceFnBtn"
) as HTMLButtonElement;
const marketplaceFnSignatureInput = document.getElementById(
  "marketplaceFnSignature"
) as HTMLInputElement;
const marketplaceFnArgsInput = document.getElementById(
  "marketplaceFnArgs"
) as HTMLInputElement;
const marketplaceFnResult = document.getElementById(
  "marketplaceFnResult"
) as HTMLElement;
const marketplaceIsWriteTx = document.getElementById(
  "marketplaceIsWriteTx"
) as HTMLInputElement;

callMarketplaceFnBtn.onclick = async function () {
  await callMarketplaceFn({
    proxyAddr: testMarketplaceProxyInput.value.trim(),
    fnSig: marketplaceFnSignatureInput.value.trim(),
    fnArgs: marketplaceFnArgsInput.value.trim()
      ? marketplaceFnArgsInput.value.trim().split(",")
      : [],
    isWrite: marketplaceIsWriteTx.checked,
    fnResult: marketplaceFnResult,
  });
};

// --- Batch Sender Section ---
const deploySenderBtn = document.getElementById(
  "deploySenderBtn"
) as HTMLButtonElement;
const senderMaxBatchInput = document.getElementById(
  "senderMaxBatch"
) as HTMLInputElement;
const senderOwnerInput = document.getElementById(
  "senderOwner"
) as HTMLInputElement; // optional
const senderOut = document.getElementById("deploySenderOutput") as HTMLElement;
const copySenderBtn = document.getElementById(
  "copySenderBtn"
) as HTMLButtonElement;

deploySenderBtn.onclick = async function () {
  await deployBatchSender({
    maxBatch: senderMaxBatchInput.value.trim() || "100",
    initialOwner: senderOwnerInput.value.trim() as `0x${string}` | undefined,
    out: senderOut,
    copyBtn: copySenderBtn,
  });
};

copySenderBtn.onclick = function () {
  const addr = (window as any).batchSenderDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copySenderBtn.innerText = "Copied!";
    setTimeout(() => (copySenderBtn.innerText = "Copy Address"), 1200);
  }
};

// --- Registry ---
const deployRegistryBtn = document.getElementById(
  "deployRegistryBtn"
) as HTMLButtonElement;
const registryProxyToggle = document.getElementById(
  "registryDeployProxy"
) as HTMLInputElement;
const deployRegistryOutput = document.getElementById(
  "deployRegistryOutput"
) as HTMLElement;
const copyRegistryBtn = document.getElementById(
  "copyRegistryBtn"
) as HTMLButtonElement;

deployRegistryBtn.onclick = async function () {

  console.log("Deploy Registry clicked");
  await deployRegistry({
    asProxy: registryProxyToggle.checked,
    out: deployRegistryOutput,
    copyBtn: copyRegistryBtn,
  });
};
copyRegistryBtn.onclick = function () {
  const addr = (window as any).registryDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copyRegistryBtn.innerText = "Copied!";
    setTimeout(() => (copyRegistryBtn.innerText = "Copy Address"), 1200);
  }
};

// --- Engine ---
const deployEngineBtn = document.getElementById(
  "deployEngineBtn"
) as HTMLButtonElement;
const engineProxyToggle = document.getElementById(
  "engineDeployProxy"
) as HTMLInputElement;
const engineRegistryInput = document.getElementById(
  "engineRegistryAddr"
) as HTMLInputElement;
const deployEngineOutput = document.getElementById(
  "deployEngineOutput"
) as HTMLElement;
const copyEngineBtn = document.getElementById(
  "copyEngineBtn"
) as HTMLButtonElement;

deployEngineBtn.onclick = async function () {
  await deployEngine({
    registryAddr: engineRegistryInput.value.trim(),
    asProxy: engineProxyToggle.checked,
    out: deployEngineOutput,
    copyBtn: copyEngineBtn,
  });
};
copyEngineBtn.onclick = function () {
  const addr = (window as any).engineDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copyEngineBtn.innerText = "Copied!";
    setTimeout(() => (copyEngineBtn.innerText = "Copy Address"), 1200);
  }
};

// --- Wire Incentives ---
const wireBtn = document.getElementById("wireBtn") as HTMLButtonElement;
const wireOut = document.getElementById("wireOutput") as HTMLElement;
const wireMarket = document.getElementById("wireMarket") as HTMLInputElement;
const wireEngineAddr = document.getElementById(
  "wireEngine"
) as HTMLInputElement;
const wireCollection = document.getElementById(
  "wireCollection"
) as HTMLInputElement;
const wirePoolBps = document.getElementById("wirePoolBps") as HTMLInputElement;
const wireTreasury = document.getElementById(
  "wireTreasury"
) as HTMLInputElement;

wireBtn.onclick = async function () {
  await wireIncentives({
    marketplaceProxy: wireMarket.value.trim(),
    engineAddr: wireEngineAddr.value.trim(),
    collectionAddr: wireCollection.value.trim(),
    poolBps: Number(wirePoolBps.value || "0"),
    treasuryAddr: wireTreasury.value.trim(),
    out: wireOut,
  });
};

// ===============================
// === REFERRAL REGISTRY TESTS ===
// ===============================
const getRegistryImplBtn = document.getElementById(
  "getRegistryImplBtn"
) as HTMLButtonElement;
const testRegistryProxyInput = document.getElementById(
  "testRegistryProxyAddress"
) as HTMLInputElement;
const registryCurrentImplResult = document.getElementById(
  "registryCurrentImplResult"
) as HTMLElement;

getRegistryImplBtn.onclick = async function () {
  await getRegistryImplAddress(
    testRegistryProxyInput.value.trim(),
    registryCurrentImplResult
  );
};

const callRegistryFnBtn = document.getElementById(
  "callRegistryFnBtn"
) as HTMLButtonElement;
const registryFnSignatureInput = document.getElementById(
  "registryFnSignature"
) as HTMLInputElement;
const registryFnArgsInput = document.getElementById(
  "registryFnArgs"
) as HTMLInputElement;
const registryFnResult = document.getElementById(
  "registryFnResult"
) as HTMLElement;
const registryIsWriteTx = document.getElementById(
  "registryIsWriteTx"
) as HTMLInputElement;

callRegistryFnBtn.onclick = async function () {
  await callRegistryFn({
    proxyAddr: testRegistryProxyInput.value.trim(),
    fnSig: registryFnSignatureInput.value.trim(),
    fnArgs: registryFnArgsInput.value.trim()
      ? registryFnArgsInput.value.trim().split(",")
      : [],
    isWrite: registryIsWriteTx.checked,
    fnResult: registryFnResult,
  });
};

// ============================
// === INCENTIVE ENGINE TEST ===
// ============================
const getEngineImplBtn = document.getElementById(
  "getEngineImplBtn"
) as HTMLButtonElement;
const testEngineProxyInput = document.getElementById(
  "testEngineProxyAddress"
) as HTMLInputElement;
const engineCurrentImplResult = document.getElementById(
  "engineCurrentImplResult"
) as HTMLElement;

getEngineImplBtn.onclick = async function () {
  await getEngineImplAddress(
    testEngineProxyInput.value.trim(),
    engineCurrentImplResult
  );
};

const callEngineFnBtn = document.getElementById(
  "callEngineFnBtn"
) as HTMLButtonElement;
const engineFnSignatureInput = document.getElementById(
  "engineFnSignature"
) as HTMLInputElement;
const engineFnArgsInput = document.getElementById(
  "engineFnArgs"
) as HTMLInputElement;
const engineFnResult = document.getElementById(
  "engineFnResult"
) as HTMLElement;
const engineIsWriteTx = document.getElementById(
  "engineIsWriteTx"
) as HTMLInputElement;

callEngineFnBtn.onclick = async function () {
  await callEngineFn({
    proxyAddr: testEngineProxyInput.value.trim(),
    fnSig: engineFnSignatureInput.value.trim(),
    fnArgs: engineFnArgsInput.value.trim()
      ? engineFnArgsInput.value.trim().split(",")
      : [],
    isWrite: engineIsWriteTx.checked,
    fnResult: engineFnResult,
  });
};

