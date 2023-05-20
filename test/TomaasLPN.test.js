const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

require("dotenv").config();

let usdc;

describe("TomaasLPN", function () {
  let TomaasLPN, tomaasLPN, owner, addr1;
  let tokenURI = "https://ipfs.io/ipfs/Qm..."; // Add your tokenURI here
  const HUN_USDC = ethers.utils.parseUnits("100", 6);

  beforeEach(async () => {
    [owner, addr1] = await ethers.getSigners();

    const ERC20 = await ethers.getContractFactory("ERC20Mock");
    usdc = await upgrades.deployProxy(ERC20, ["USD Coin", "USDC"]);
    await usdc.deployed();

    await usdc.connect(owner).mint(owner.address, HUN_USDC.mul(1000000));
    await usdc.connect(owner).mint(addr1.address, HUN_USDC.mul(1000000));

    TomaasLPN = await ethers.getContractFactory("TomaasLPN");
    tomaasLPN = await upgrades.deployProxy(TomaasLPN, [usdc.address]);
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
    // it("Price ", async () => {
    //   expect(await tomaasLPN.getPrice(5)).to.equal(50);
    // });

    // it("balance", async () => {
    //   console.log(await tomaasLPN.getBalance());
    //   expect(1).to.equal(2);
    // });

    it("balance Check", async () => {
      expect(await tomaasLPN.check(5)).to.equal(false);
    });

    it("Should mint a new token", async function () {
      await usdc
        .connect(owner)
        .approve(tomaasLPN.address, ethers.utils.parseUnits("10", 6));
      await tomaasLPN.connect(owner).safeMint_mul(addr1.address, tokenURI, 1);
      expect(await tomaasLPN.balanceOf(addr1.address)).to.equal(1);
      expect(await tomaasLPN.tokenURI(0)).to.equal(tokenURI);
    });

    it("Should mint 5 new token", async function () {
      await usdc
        .connect(owner)
        .approve(tomaasLPN.address, ethers.utils.parseUnits("50", 6));
      await tomaasLPN.connect(owner).safeMint_mul(addr1.address, tokenURI, 5);
      expect(await tomaasLPN.balanceOf(addr1.address)).to.equal(5);
      expect(await tomaasLPN.tokenURI(0)).to.equal(tokenURI);
    });

    it("Should fail if a non-owner tries to mint", async function () {
      await usdc
        .connect(addr1)
        .approve(tomaasLPN.address, ethers.utils.parseUnits("10", 1));
      await expect(
        tomaasLPN.connect(addr1).safeMint_mul(addr1.address, tokenURI, 1)
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });
});
