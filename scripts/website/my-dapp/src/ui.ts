import { ethers } from "ethers";

function appendMessage(el: any, html: any, maxMessages = 10) {
  // Get existing messages as an array (including .success and .error)
  const existing = Array.from(el.querySelectorAll('.success, .error'));
  // Build new content: last (maxMessages-1) + new message
  const newMessages = existing.slice(-maxMessages + 1).map(n => (n as any).outerHTML);
  newMessages.push(html);

  // Set new innerHTML to keep max N messages and scroll to top
  el.innerHTML = newMessages.join("<br>");
  el.scrollTop = 0; // Reset scroll to top if scrolling is enabled
}
export function showError(el: any, msg: any, maxMessages = 10) {
  appendMessage(el, `<span class="error">${msg.replace(/\n/g, "<br>")}</span>`, maxMessages);
}
export function showSuccess(el: any, msg: any, maxMessages = 10) {
  appendMessage(el, `<span class="success">${msg.replace(/\n/g, "<br>")}</span>`, maxMessages);
}

export function autofillFeeRecipient(recipientInput: HTMLInputElement) {
  if ((window as any).ethereum) {
    (window as any).ethereum
      .request({ method: "eth_requestAccounts" })
      .then(async () => {
        const provider = new ethers.BrowserProvider((window as any).ethereum);
        const signer = await provider.getSigner();
        recipientInput.value = await signer.getAddress();
      })
      .catch(() => {});
  }
}
