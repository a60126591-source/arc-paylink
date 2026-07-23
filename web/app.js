const CONFIG = window.ARCPAYLINK_CONFIG;
const ABI = [
  "function createRequest(address recipient,uint256 amount,string title,string memo) returns (uint256)",
  "function payRequest(uint256 requestId) payable",
  "function cancelRequest(uint256 requestId)",
  "function getRequest(uint256 requestId) view returns ((address creator,address recipient,uint256 amount,string title,string memo,bool paid,bool cancelled,address payer,uint256 createdAt,uint256 paidAt))",
  "function nextRequestId() view returns (uint256)",
  "event PaymentRequestCreated(uint256 indexed requestId,address indexed creator,address indexed recipient,uint256 amount,string title,string memo)"
];
const CHAIN_HEX = "0x4cef52";
let provider;
let signer;
let contract;
let loadedRequest;

const $ = (id) => document.getElementById(id);
const toast = (message) => {
  $("toast").textContent = message;
  $("toast").classList.add("show");
  setTimeout(() => $("toast").classList.remove("show"), 4200);
};
const short = (address) => `${address.slice(0, 6)}…${address.slice(-4)}`;
const formatDate = (timestamp) => timestamp === 0n ? "—" : new Date(Number(timestamp) * 1000).toLocaleString();

function requireContractAddress() {
  if (!ethers.isAddress(CONFIG.contractAddress)) {
    throw new Error("Contract address has not been added to web/config.js yet.");
  }
}

async function switchToArc() {
  try {
    await window.ethereum.request({ method: "wallet_switchEthereumChain", params: [{ chainId: CHAIN_HEX }] });
  } catch (error) {
    if (error.code !== 4902) throw error;
    await window.ethereum.request({
      method: "wallet_addEthereumChain",
      params: [{
        chainId: CHAIN_HEX,
        chainName: "Arc Testnet",
        nativeCurrency: { name: "USDC", symbol: "USDC", decimals: 18 },
        rpcUrls: [CONFIG.rpcUrl],
        blockExplorerUrls: [CONFIG.explorerUrl]
      }]
    });
  }
}

async function connectWallet() {
  requireContractAddress();
  if (!window.ethereum) throw new Error("Open this page inside a wallet browser such as MetaMask or use a browser with an injected wallet.");
  await switchToArc();
  provider = new ethers.BrowserProvider(window.ethereum);
  signer = await provider.getSigner();
  contract = new ethers.Contract(CONFIG.contractAddress, ABI, signer);
  const address = await signer.getAddress();
  $("walletStatus").textContent = `Connected: ${short(address)}`;
  $("connectButton").textContent = short(address);
  toast("Wallet connected to Arc Testnet.");
}

async function ensureConnected() {
  if (!contract) await connectWallet();
}

function renderRequest(request, id) {
  return [
    `Request #${id}`,
    `Title: ${request.title}`,
    `Memo: ${request.memo || "—"}`,
    `Amount: ${ethers.formatEther(request.amount)} USDC`,
    `Creator: ${request.creator}`,
    `Recipient: ${request.recipient}`,
    `Status: ${request.cancelled ? "Cancelled" : request.paid ? "Paid" : "Open"}`,
    `Payer: ${request.payer === ethers.ZeroAddress ? "—" : request.payer}`,
    `Created: ${formatDate(request.createdAt)}`,
    `Paid: ${formatDate(request.paidAt)}`
  ].join("\n");
}

$("connectButton").addEventListener("click", () => connectWallet().catch((e) => toast(e.shortMessage || e.message)));

$("createButton").addEventListener("click", async () => {
  try {
    await ensureConnected();
    const recipient = $("recipient").value.trim();
    const amount = $("amount").value.trim();
    const title = $("title").value.trim();
    const memo = $("memo").value.trim();
    if (!ethers.isAddress(recipient)) throw new Error("Enter a valid recipient address.");
    if (!amount || Number(amount) <= 0) throw new Error("Enter an amount greater than zero.");
    if (!title) throw new Error("Enter a title.");
    const tx = await contract.createRequest(recipient, ethers.parseEther(amount), title, memo);
    toast("Transaction submitted. Waiting for confirmation…");
    const receipt = await tx.wait();
    let requestId = "new";
    for (const log of receipt.logs) {
      try {
        const parsed = contract.interface.parseLog(log);
        if (parsed?.name === "PaymentRequestCreated") requestId = parsed.args.requestId.toString();
      } catch {}
    }
    $("inspectId").value = requestId === "new" ? "" : requestId;
    toast(`Payment request #${requestId} created.`);
  } catch (e) { toast(e.shortMessage || e.reason || e.message); }
});

$("loadPayButton").addEventListener("click", async () => {
  try {
    await ensureConnected();
    const id = $("payId").value;
    if (id === "") throw new Error("Enter a request ID.");
    loadedRequest = await contract.getRequest(id);
    $("payPreview").textContent = renderRequest(loadedRequest, id);
    $("payPreview").classList.remove("muted");
    $("payButton").disabled = loadedRequest.paid || loadedRequest.cancelled;
  } catch (e) { toast(e.shortMessage || e.reason || e.message); }
});

$("payButton").addEventListener("click", async () => {
  try {
    await ensureConnected();
    const id = $("payId").value;
    if (!loadedRequest) throw new Error("Load the request first.");
    const tx = await contract.payRequest(id, { value: loadedRequest.amount });
    toast("Payment submitted. Waiting for confirmation…");
    await tx.wait();
    $("payButton").disabled = true;
    toast(`Request #${id} paid successfully.`);
  } catch (e) { toast(e.shortMessage || e.reason || e.message); }
});

$("inspectButton").addEventListener("click", async () => {
  try {
    requireContractAddress();
    const id = $("inspectId").value;
    if (id === "") throw new Error("Enter a request ID.");
    const readProvider = provider || new ethers.JsonRpcProvider(CONFIG.rpcUrl);
    const readContract = new ethers.Contract(CONFIG.contractAddress, ABI, readProvider);
    const request = await readContract.getRequest(id);
    $("inspectOutput").textContent = renderRequest(request, id);
  } catch (e) { toast(e.shortMessage || e.reason || e.message); }
});

if (ethers.isAddress(CONFIG.contractAddress)) {
  $("contractLink").href = `${CONFIG.explorerUrl}/address/${CONFIG.contractAddress}`;
} else {
  $("contractLink").textContent = "Deploy contract first";
  $("contractLink").removeAttribute("href");
}
