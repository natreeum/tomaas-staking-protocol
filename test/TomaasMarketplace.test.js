const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");

const { expect } = require("chai");

require("dotenv").config();

describe("TomaasMarketplace", function () {
  let owner, renter, holder, buyer, holder2, renter2, buyer2;
  let tomaasNFT, tomaasProtocol, tomaasMarketplace;
  let usdc;

  const NFT_URI = "https://www.tomaas.ai/nft";
  const ONE_USDC = ethers.utils.parseUnits("1", 6);
  const TWO_USDC = ethers.utils.parseUnits("2", 6);
  const USDC_DECIMALS = 6;

  const COLLECTION_NAME_1 = "TomaasNFT #1";

  const TOKEN_ID = 0;
  const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  const TOKEN_NAME = "Trustless Ondemand Mobility Vehicle Ownership pre #1";
  const TOKEN_SYMBOL = "TMN";

  beforeEach(async function () {
    [owner, holder, renter, buyer, holder2, renter2, buyer2] = await ethers.getSigners();

    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    usdc = await ERC20.deploy("USD Coin", "USDC");
    await usdc.deployed();

    await usdc.connect(owner).mint(owner.address, TWO_USDC.mul(1000000));
    await usdc.connect(owner).mint(holder.address, TWO_USDC.mul(1000000));
    await usdc.connect(owner).mint(buyer.address, TWO_USDC.mul(1000000));

    // Deploy TomaasNFT
    const TomaasNFT = await ethers.getContractFactory("TomaasNFT");
    tomaasNFT = await TomaasNFT.deploy(COLLECTION_NAME_1, usdc.address);
    await tomaasNFT.deployed();

    const TomaasProtocol = await ethers.getContractFactory("TomaasProtocol");
    tomaasProtocol = await TomaasProtocol.deploy();
    await tomaasProtocol.deployed();

    await tomaasNFT.connect(owner).transferOwnership(tomaasProtocol.address);
    await tomaasProtocol.connect(owner).addCollection(tomaasNFT.address); 

    // Deploy the TomaasMarketplace contract
    const TomaasMarketplace = await ethers.getContractFactory("TomaasMarketplace");
    tomaasMarketplace = await TomaasMarketplace.deploy(tomaasProtocol.address);
    await tomaasMarketplace.deployed();

    await tomaasProtocol.safeMintNFT(tomaasNFT.address, holder.address, NFT_URI);

    const price = ONE_USDC.mul(1000000);
    await tomaasMarketplace.connect(holder).listingForSale(tomaasNFT.address, TOKEN_ID, price);

  });

  describe("listing", function () {
    it("should allow a seller to list an NFT for sale", async function () {
      expect(await tomaasMarketplace.isForSale(tomaasNFT.address, TOKEN_ID)).to.equal(true);
    });
  });

  describe("buying", function () {
    it("should not allow a buyer to buy an NFT for an incorrect price", async function () {
      const price = TWO_USDC.mul(1000000);
      await expect(tomaasMarketplace.connect(buyer).buyNFT(tomaasNFT.address, TOKEN_ID, price)).to.be.revertedWith("TM: price is not correct");
    });
  
    it("should not allow a buyer to buy an NFT if they do not have enough tokens", async function () {
      const price = ONE_USDC.mul(1000000);
      await expect(tomaasMarketplace.connect(buyer2).buyNFT(tomaasNFT.address, TOKEN_ID, price)).to.be.revertedWith("TM: not enough token balance");
    });

  });

});