const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

require("dotenv").config();

describe("TomaasProtocol", function () {
    let owner, renter, holder, buyer, holder2, renter2, buyer2;
    let TomaasRWN, tomaasRWN;
    let usdc;

    const NFT_URI = "https://www.tomaas.ai/nft";
    const ONE_USDC = ethers.utils.parseUnits("1", 6);
    const TWO_USDC = ethers.utils.parseUnits("2", 6);
    const USDC_DECIMALS = 6;

    const TOKEN_ID = 0;
    const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
    const TOKEN_NAME = "Trustless Ondemand Mobility Vehicle Ownership pre #1";
    const TOKEN_SYMBOL = "RWN";

    const COLLECTION_NAME_1 = "TomaasRWN #1";
    const COLLECTION_NAME_2 = "TomaasRWN #2";
    const collectionSupply = 10;

    beforeEach(async function () {
        [owner, holder, renter, buyer, holder2, renter2, buyer2] = await ethers.getSigners();
    
        const ERC20 = await ethers.getContractFactory("ERC20Mock");
        usdc = await ERC20.deploy("USD Coin", "USDC");
        await usdc.deployed();

        await usdc.connect(owner).mint(owner.address, TWO_USDC.mul(1000000));
        await usdc.connect(owner).mint(holder.address, TWO_USDC.mul(1000000));
        await usdc.connect(owner).mint(renter.address, TWO_USDC.mul(1000000));

        // Deploy TomaasRWN
        const TomaasRWN = await ethers.getContractFactory("TomaasRWN");
        tomaasRWN = await TomaasRWN.deploy(COLLECTION_NAME_1, usdc.address);
        await tomaasRWN.deployed();

        const TomaasProtocol = await ethers.getContractFactory("TomaasProtocol");
        tomaasProtocol = await TomaasProtocol.deploy();
        await tomaasProtocol.deployed();

        await tomaasRWN.connect(owner).transferOwnership(tomaasProtocol.address);
        await tomaasProtocol.connect(owner).addCollection(tomaasRWN.address); 
    });

    describe("collection", function () {
        it("should add a new collection", async function () {
          // Test case code
          const tomNFT2 = await (await ethers.getContractFactory("TomaasRWN")).deploy(COLLECTION_NAME_2, usdc.address);
          await tomNFT2.deployed();

          const tx = await tomaasProtocol.addCollection(tomNFT2.address);
          await tx.wait();

          expect(await tomaasProtocol.getCollectionIndex(tomNFT2.address)).to.equal(1);
          expect(await tomaasProtocol.getCollections()).to.have.length(2);
          const collection = await tomaasProtocol.getCollectionAt(1);
          expect(collection.tomaasRWN).to.equal(tomNFT2.address);
          expect(collection.acceptedToken).to.equal(usdc.address);
        });
        it("should revert if NFT address is zero", async function () {
          await expect(tomaasProtocol.addCollection(ethers.constants.AddressZero)).to.be.revertedWith("TP: NFT Addr=0");
        });
      });

      describe("list for Rent", async function () {
        it("should revert if it is not approved", async function () {
          await tomaasProtocol.safeMintNFT(tomaasRWN.address, holder.address, NFT_URI);
          await expect(tomaasProtocol.connect(holder).listingNFT(
            tomaasRWN.address, TOKEN_ID)).to.be.revertedWith("TP: notApproved");
        });
        it("should allow listing of NFTs when approve is used", async function () {
          await tomaasProtocol.safeMintNFT(tomaasRWN.address, holder.address, NFT_URI);
          await tomaasRWN.connect(holder).approve(tomaasProtocol.address, TOKEN_ID);
          await tomaasProtocol.connect(holder).listingNFT(tomaasRWN.address, TOKEN_ID);
          const nfts = await tomaasProtocol.getListingNFTs(tomaasRWN.address);
          expect(nfts.length).to.equal(1);
        });
        it("should allow listing of NFTs when setApprovalForAll is used", async function () {
          await tomaasProtocol.safeMintNFT(tomaasRWN.address, holder.address, NFT_URI);
          await tomaasRWN.connect(holder).setApprovalForAll(tomaasProtocol.address, true);
          await tomaasProtocol.connect(holder).listingNFT(tomaasRWN.address, TOKEN_ID);
          const nfts = await tomaasProtocol.getListingNFTs(tomaasRWN.address);
          expect(nfts.length).to.equal(1);
        });
      });
});
