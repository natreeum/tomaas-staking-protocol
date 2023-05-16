const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

require("dotenv").config();

describe("TomaasLPN", function () {
  let TomaasLPN, tomaasLPN, owner, addr1;
  let tokenURI = "https://ipfs.io/ipfs/Qm..."; // Add your tokenURI here

  beforeEach(async () => {
      [owner, addr1] = await ethers.getSigners();
      TomaasLPN = await ethers.getContractFactory("TomaasLPN");
      tomaasLPN = await upgrades.deployProxy(TomaasLPN);
      await tomaasLPN.deployed();
  });

  describe("Deployment", function () {
      it("Should set the right owner", async function () {
          expect(await tomaasLPN.owner()).to.equal(owner.address);
      });

      it("Should initialize the contract", async function () {
          expect(await tomaasLPN.name()).to.equal("Tomaas Liquidity Provider NFT");
          expect(await tomaasLPN.symbol()).to.equal("TLN");
      });

      it("should pause and unpause the contract", async function () {
        expect(await tomaasLPN.paused()).to.equal(false);
    
        await tomaasLPN.pause();
        expect(await tomaasLPN.paused()).to.equal(true);
    
        await tomaasLPN.unpause();
        expect(await tomaasLPN.paused()).to.equal(false);
      });
  });

  describe("Transactions", function () {
      it("Should mint a new token", async function () {
          await tomaasLPN.connect(owner).safeMint(addr1.address, tokenURI);
          expect(await tomaasLPN.balanceOf(addr1.address)).to.equal(1);
          expect(await tomaasLPN.tokenURI(0)).to.equal(tokenURI);
      });

      it("Should fail if a non-owner tries to mint", async function () {
          await expect(
              tomaasLPN.connect(addr1).safeMint(addr1.address, tokenURI)
          ).to.be.revertedWith("Ownable: caller is not the owner");
      });
  });
});