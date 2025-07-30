import { deployContract } from "./deploy";
import { upgradeContract } from "./upgrade.ts";
import { getImplementationAddress, callProxyFunction } from "./testProxy.ts";
import { autofillFeeRecipient } from "./ui";

// --- DOM refs ---
const out = document.getElementById("output") as HTMLElement;
const deployBtn = document.getElementById("deployBtn") as HTMLButtonElement;
const copyBtn = document.getElementById("copyBtn") as HTMLButtonElement;
const feeInput = document.getElementById("deploymentFee") as HTMLInputElement;
const recipientInput = document.getElementById("feeRecipient") as HTMLInputElement;
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
  const addr = (window as any).contractDeployedAddress;
  if (addr) {
    navigator.clipboard.writeText(addr);
    copyBtn.innerText = "Copied!";
    setTimeout(() => {
      copyBtn.innerText = "Copy Address";
    }, 1200);
  }
};

// UPGRADE
const deployAndUpgradeBtn = document.getElementById("deployAndUpgradeBtn") as HTMLButtonElement;
const upgradeProxyInput = document.getElementById("upgradeProxyAddress") as HTMLInputElement;
const upgradeTypeInput = document.getElementById("upgradeContractType") as HTMLInputElement;
const upgradeOutput = document.getElementById("upgradeOutput") as HTMLElement;
const initFnNameInput = document.getElementById("initFnName") as HTMLInputElement;
const initFnArgsInput = document.getElementById("initFnArgs") as HTMLInputElement;

deployAndUpgradeBtn.onclick = async function () {
  await upgradeContract({
    proxyAddr: upgradeProxyInput.value.trim(),
    contractType: upgradeTypeInput.value.trim() || "CollectionFactory",
    initFnName: initFnNameInput.value.trim(),
    initFnArgsRaw: initFnArgsInput.value.trim(),
    upgradeOutput,
  });
};

// TEST PROXY
const getImplBtn = document.getElementById("getImplBtn") as HTMLButtonElement;
const testProxyInput = document.getElementById("testProxyAddress") as HTMLInputElement;
const currentImplResult = document.getElementById("currentImplResult") as HTMLElement;

getImplBtn.onclick = async function () {
  await getImplementationAddress(testProxyInput.value.trim(), currentImplResult);
};

const callFnBtn = document.getElementById("callFnBtn") as HTMLButtonElement;
const fnSignatureInput = document.getElementById("fnSignature") as HTMLInputElement;
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
