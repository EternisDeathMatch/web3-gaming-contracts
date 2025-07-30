import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

const RPC_URL = process.env.XDC_RPC_URL!;
const CONTRACT_ADDRESS = "0xB012bf6C53eAc300389cE4458F82CC8B1A29Dc7d";

const abi = [
  "function getCurrentTokenId() view returns (uint256)",
  "function tokenURI(uint256 tokenId) view returns (string)"
];

async function main() {
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const contract = new ethers.Contract(CONTRACT_ADDRESS, abi, provider);

  const totalMinted: number = Number(await contract.getCurrentTokenId());
  console.log(`Total minted tokens: ${totalMinted}`);

  if (totalMinted === 0) {
    console.log("No tokens minted yet.");
    return;
  }

  console.log("Fetching token metadata...");
  for (let tokenId = 0; tokenId < totalMinted; tokenId++) {
    try {
      let uri: string = await contract.tokenURI(tokenId);
      console.log(`\nToken #${tokenId}`);
      console.log(`\URI #${uri}`);

      // If you’re using ipfs:// URIs, convert them to a public gateway:
      if (uri.startsWith("ipfs://")) {
        uri = uri.replace(
          /^ipfs:\/\//,
          "https://ipfs.io/ipfs/"
        );
      }

      // Fetch the JSON metadata and parse
      const resp = await fetch(uri);
      if (!resp.ok) {
        throw new Error(`HTTP ${resp.status} fetching ${uri}`);
      }
      const metadata = await resp.json();

      console.log(`\nToken #${tokenId}`);
      console.log("Name:       ", metadata.name);
      console.log("Description:", metadata.description);
      console.log("Image URL:  ", metadata.image);
      // any other fields...
    } catch (err) {
      console.error(`Error loading metadata for token ${tokenId}:`, err);
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
