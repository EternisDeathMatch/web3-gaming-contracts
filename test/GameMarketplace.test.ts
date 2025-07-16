import { ethers } from "hardhat";
import { expect } from "chai";
import "@nomicfoundation/hardhat-chai-matchers";
import type { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import type { GameMarketplace } from "../typechain/contracts/GameMarketplace";
import type { GameNFTCollection } from "../typechain/contracts/GameNFTCollection";
describe("GameMarketplace", function () {
  let marketplace: GameMarketplace;
  let nftCollection: GameNFTCollection;
  let owner: SignerWithAddress, seller: SignerWithAddress, buyer: SignerWithAddress;

  beforeEach(async function () {
    [owner, seller, buyer] = await ethers.getSigners() as SignerWithAddress[];

    const Marketplace = await ethers.getContractFactory("GameMarketplace");
    marketplace = (await Marketplace.deploy(owner.address)) as GameMarketplace;
    await marketplace.waitForDeployment();

    const NFTCollection = await ethers.getContractFactory("GameNFTCollection");
    nftCollection = (await NFTCollection.deploy(
      "TestNFT",
      "TNFT",
      "Description",
      "https://example.com/",
      100,
      seller.address,
      seller.address,
      500
    )) as GameNFTCollection;
    await nftCollection.waitForDeployment();

    await nftCollection.connect(seller).mint(seller.address, "tokenURI1");
  });

  it("handles native token sale with correct fee & royalty distribution", async function () {
    await nftCollection.connect(seller).setApprovalForAll(marketplace.target, true);
    const price = ethers.parseEther("1");
    const duration = 3600;
    await expect(
      marketplace.connect(seller).listItem(
        nftCollection.target,
        0,
        ethers.ZeroAddress,
        price,
        duration
      )
    ).to.emit(marketplace, "ItemListed");

    const listingId = await marketplace.activeListing(nftCollection.target, 0);

    const platformFee = price * 250n / 10000n;
    const royaltyFee = price * 500n / 10000n;
    const sellerProceeds = price - platformFee - royaltyFee;

    await expect(() =>
      marketplace.connect(buyer).buyItem(listingId, { value: price })
    ).to.changeEtherBalances(
      [buyer, seller, owner],
      [-price, sellerProceeds + royaltyFee, platformFee]
    );

    expect(await nftCollection.ownerOf(0)).to.equal(buyer.address);
  });

  it("allows canceling a listing", async function () {
    await nftCollection.connect(seller).setApprovalForAll(marketplace.target, true);
    await marketplace.connect(seller).listItem(nftCollection.target, 0, ethers.ZeroAddress, 1, 3600);
    const listingId = await marketplace.activeListing(nftCollection.target, 0);
    await expect(marketplace.connect(seller).cancelListing(listingId)).to.emit(
      marketplace,
      "ListingCancelled"
    );
    expect(await marketplace.isListingValid(listingId)).to.be.false;
  });

  it("supports ERC20 payment", async function () {
    // Use a mock ERC20 with initial supply
    const Token = await ethers.getContractFactory("MockERC20");
    const initialBalance = ethers.parseUnits("1000000", 18);
    const token: any = await Token.deploy("TestToken", "TT", initialBalance);
    await token.waitForDeployment();

    // Distribute tokens to buyer
    const amt = ethers.parseUnits("1000", 18);
    await token.connect(owner).transfer(buyer.address, amt);

    // Enable marketplace to accept this token
    await marketplace.connect(owner).addSupportedToken(token.target);
    await token.connect(buyer).approve(marketplace.target, amt);

    // Seller lists NFT
    await nftCollection.connect(seller).setApprovalForAll(marketplace.target, true);
    const price = ethers.parseUnits("100", 18);
    await marketplace.connect(seller).listItem(nftCollection.target, 0, token.target, price, 3600);
    const listingId = await marketplace.activeListing(nftCollection.target, 0);

    // Buyer buys with ERC20
    await expect(() =>
      marketplace.connect(buyer).buyItem(listingId)
    ).to.changeTokenBalances(
      token,
      [buyer, owner],
      [-price, price * 250n / 10000n]
    );

    expect(await nftCollection.ownerOf(0)).to.equal(buyer.address);
  });

  it("allows pausing and unpausing marketplace", async function () {
    await marketplace.connect(owner).pause();
    await expect(
      marketplace.connect(seller).listItem(nftCollection.target, 0, ethers.ZeroAddress, 1, 3600)
    ).to.be.revertedWith("Pausable: paused");

    await marketplace.connect(owner).unpause();
    await nftCollection.connect(seller).setApprovalForAll(marketplace.target, true);
    await expect(
      marketplace.connect(seller).listItem(nftCollection.target, 0, ethers.ZeroAddress, 1, 3600)
    ).to.emit(marketplace, "ItemListed");
  });
});
