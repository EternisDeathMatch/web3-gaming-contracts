import { ethers } from "hardhat";
import { expect } from "chai";
import "@nomicfoundation/hardhat-chai-matchers";
import type { CollectionFactory } from "../typechain/contracts/CollectionFactory";

describe("CollectionFactory", function () {
  let factory: CollectionFactory;
  let ownerAddress: string;
  let userAddress: string;
  const initialFee = ethers.parseEther("0.01");
  const gameId = 1;

  beforeEach(async function () {
    const [owner, user] = await ethers.getSigners();
    ownerAddress = await owner.getAddress();
    userAddress = await user.getAddress();
    const Factory = await ethers.getContractFactory("CollectionFactory");
    factory = (await Factory.deploy(
      initialFee,
      ownerAddress
    )) as CollectionFactory;
    await factory.waitForDeployment();
  });

  it("sets deployment fee and recipient correctly", async function () {
    expect(await factory.deploymentFee()).to.equal(initialFee);
    expect(await factory.feeRecipient()).to.equal(ownerAddress);
  });

  it("deploys a new collection when fee is paid", async function () {
    const tx = factory
      .connect(await ethers.getSigner(userAddress))
      .deployCollection(
        gameId,
        "Game",
        "GM",
        "Desc",
        "uri/",
        10,
        userAddress,
        100,
        { value: initialFee }
      );
    const { anyValue } = await import(
      "@nomicfoundation/hardhat-chai-matchers/withArgs"
    );
    await expect(tx)
      .to.emit(factory, "CollectionDeployed")
      .withArgs(anyValue, userAddress, gameId, "Game", "GM", 10n);

    const collections = await factory.getUserCollections(userAddress);
    expect(collections.length).to.equal(1);
  });

  it("reverts if insufficient fee", async function () {
    await expect(
      factory
        .connect(await ethers.getSigner(userAddress))
        .deployCollection(gameId, "G", "G", "D", "u/", 5, userAddress, 50, {
          value: 0,
        })
    ).to.be.revertedWith("Insufficient deployment fee");
  });

  it("allows owner to update fee and recipient", async function () {
    const newFee = ethers.parseEther("0.02");
    await factory.updateDeploymentFee(newFee);
    expect(await factory.deploymentFee()).to.equal(newFee);

    await factory.updateFeeRecipient(userAddress);
    expect(await factory.feeRecipient()).to.equal(userAddress);
  });

  it("only owner can update settings", async function () {
    await expect(
      factory
        .connect(await ethers.getSigner(userAddress))
        .updateDeploymentFee(initialFee)
    ).to.be.revertedWith("Ownable: caller is not the owner");
  });

  it("reverts withdraw when no fees accumulated", async function () {
    await expect(factory.withdrawFees()).to.be.revertedWith(
      "No fees to withdraw"
    );
  });

  it("correctly reports deployed vs non-deployed collections", async function () {
    // deploy one collection
    await factory
      .connect(await ethers.getSigner(userAddress))
      .deployCollection(gameId, "X", "X", "Desc", "uri/", 1, userAddress, 0, {
        value: initialFee,
      });

    const collections = await factory.getUserCollections(userAddress);
    expect(collections.length).to.equal(1);

    const deployedAddr = collections[0];
    expect(await factory.verifyCollection(deployedAddr)).to.equal(true);

    expect(await factory.verifyCollection(ethers.ZeroAddress)).to.equal(false);
  });

  it("tracks total collections count properly", async function () {
    expect(await factory.getTotalCollections()).to.equal(0n);

    await factory
      .connect(await ethers.getSigner(userAddress))
      .deployCollection(gameId, "A", "A", "Desc", "uri/", 1, userAddress, 0, {
        value: initialFee,
      });
    expect(await factory.getTotalCollections()).to.equal(1n);

    await factory
      .connect(await ethers.getSigner(userAddress))
      .deployCollection(gameId, "B", "B", "Desc", "uri/", 1, userAddress, 0, {
        value: initialFee,
      });
    expect(await factory.getTotalCollections()).to.equal(2n);
  });
});
