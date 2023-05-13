const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("TomaasNFT", function () {
    let owner, renter, holder, buyer, holder2, renter2, buyer2;
    let TomaasNFT, tomaasNFT;
    let usdc;

    const NFT_URI = "https://www.tomaas.ai/nft";
    const ONE_USDC = ethers.utils.parseUnits("1", 6);
    const TWO_USDC = ethers.utils.parseUnits("2", 6);
    const USDC_DECIMALS = 6;

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
        await usdc.connect(owner).mint(renter.address, TWO_USDC.mul(1000000));

        TomaasNFT = await ethers.getContractFactory("TomaasNFT");
        tomaasNFT = await TomaasNFT.deploy(TOKEN_NAME, usdc.address);
        await tomaasNFT.deployed();
    });

    describe("mint", function () {
        it("should mint a new token with the given URI", async function () {
            expect(await tomaasNFT.name()).to.equal(TOKEN_NAME);
            expect(await tomaasNFT.symbol()).to.equal(TOKEN_SYMBOL);

            const tx = await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);
            await tx.wait();

            expect(await tomaasNFT.balanceOf(holder.address)).to.equal(1);

            const tokenURIStored = await tomaasNFT.tokenURI(TOKEN_ID);
            expect(tokenURIStored).to.equal(NFT_URI);
        });
    });

    describe("setUser", function() {
        it("should set the user and expires of a token", async function() {
          const tx = await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);
          await tx.wait();

          const expires = (await time.latest()) + 3600;
          const tx2 = await tomaasNFT.connect(holder).setUser(TOKEN_ID, renter.address, expires);
          await tx2.wait();
    
          const user = await tomaasNFT.userOf(TOKEN_ID);
          expect(user).to.equal(renter.address);
    
          const userExpires = await tomaasNFT.userExpires(TOKEN_ID);
          expect(userExpires).to.equal(expires);
        });

        it("should revert if the caller is not the token owner", async function () {
            await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);

            const expires = Math.floor(Date.now() / 1000) + 3600;
            await expect(tomaasNFT.connect(renter).setUser(
                TOKEN_ID, renter.address, expires)).to.be.revertedWith(
                    "TN: notOwnerOrAppr");
        });

        it("should revert if the token does not exist", async function () {
            const expires = Math.floor(Date.now() / 1000) + 3600;
            await expect(tomaasNFT.connect(owner).setUser(
                TOKEN_ID, renter.address, expires)).to.be.revertedWith(
                    "TN: tokenDoesNotExi");
        });

        it("should handle multiple NFTs with different users and expiries", async function () {
            // Mint two NFTs with different URIs and assign them to different users with different expiry times
            await tomaasNFT.safeMint(holder.address, "uri1");
            await tomaasNFT.safeMint(holder2.address, "uri2");
        
            const user1TokenId = 0;
            const user2TokenId = 1;
        
            const expires = (await time.latest()) + 3600;
            const expires2 = (await time.latest()) + 7200;
            const tx = await tomaasNFT.connect(holder).setUser(user1TokenId, renter.address, expires); // set user1 to expire in 1 hour
            await tx.wait();
            const tx2 = await tomaasNFT.connect(holder2).setUser(user2TokenId, renter2.address, expires2); // set user2 to expire in 2 hours
            await tx2.wait();
        
            expect(await tomaasNFT.userOf(user1TokenId)).to.equal(renter.address);
            expect(await tomaasNFT.userOf(user2TokenId)).to.equal(renter2.address);
        
            expect(await tomaasNFT.userExpires(user1TokenId)).to.equal(expires);
            expect(await tomaasNFT.userExpires(user2TokenId)).to.equal(expires2);
        
            // Wait for user1 to expire
            await time.increaseTo(await time.latest() + 4000);
        
            // Check that user1 is now expired
            expect(await tomaasNFT.userOf(user1TokenId)).to.equal(ethers.constants.AddressZero);
            expect(await tomaasNFT.userOf(user2TokenId)).to.equal(renter2.address);
        });

    });

    describe("transfer", function() {
        it("should transfer a token and keep the rental user", async function() {
          const tx = await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);
          await tx.wait();
    
          const expires = (await time.latest()) + 3600;
          const tx2 = await tomaasNFT.connect(holder).setUser(TOKEN_ID, renter.address, expires);
          await tx2.wait();
    
          const tx3 = await tomaasNFT.connect(holder).transferFrom(holder.address, buyer.address, TOKEN_ID);
          await tx3.wait();
    
          const user = await tomaasNFT.userOf(TOKEN_ID);
          expect(user).to.equal(renter.address);
        });
    
        it("should user of the token after it has expired", async function() {
            const tx = await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);
            await tx.wait();
      
            const expires = (await time.latest()) + 1;
            const tx2 = await tomaasNFT.connect(holder).setUser(TOKEN_ID, renter.address, expires);
            await tx2.wait();
      
            // wait for the rental to expire
            await time.increaseTo(await time.latest() + 10);
      
            const user = await tomaasNFT.userOf(TOKEN_ID);
            expect(user).to.equal(ethers.constants.AddressZero);
          });
      });

    describe("earnings", () => {
        it("should payout earnings for an NFT", async () => {
            const tx = await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);
            await tx.wait();
            
            const expires = (await time.latest()) + 3600;
            const tx2 = await tomaasNFT.connect(holder).setUser(TOKEN_ID, renter.address, expires);
            await tx2.wait();

            const amount = ethers.utils.parseUnits("1", USDC_DECIMALS);
            await usdc.connect(renter).approve(tomaasNFT.address, amount);
            await tomaasNFT.connect(renter).payOutEarnings(TOKEN_ID, amount);
            expect(await tomaasNFT.unClaimedEarnings(TOKEN_ID)).to.equal(amount);
        });

        it("should allow user to pay out earnings for all rented NFTs", async () => {
            await tomaasNFT.connect(owner).safeMint(holder.address, NFT_URI);
            const tx = await tomaasNFT.connect(owner).safeMint(holder.address, "NFT-uri-2");
            await tx.wait();

            const expires = (await time.latest()) + 3600;
            await tomaasNFT.connect(holder).setUser(TOKEN_ID, renter.address, expires);
            const tokenId2 = 1;
            const tx2 = await tomaasNFT.connect(holder).setUser(tokenId2, renter.address, expires);

            // Renter pays out earnings for all rented NFTs
            const amount = ethers.utils.parseUnits("2", USDC_DECIMALS);
            await usdc.connect(renter).approve(tomaasNFT.address, amount);
            await tomaasNFT.connect(renter).payOutEarningsAllRented(amount);

            const unclaimed = await tomaasNFT.unClaimedEarnings(TOKEN_ID);
            expect(unclaimed).to.equal(amount/2);

            const unclaimedAll = await tomaasNFT.connect(holder).unClaimedEarningsAll();
            expect(unclaimedAll).to.equal(amount);
        });

        it("should distribute fees to owner and balance to user upon claiming earnings", async () => {
            // mint a new NFT and set user to account1
            await tomaasNFT.safeMint(holder.address, NFT_URI);
            const expires = (await time.latest()) + 3600;
            await tomaasNFT.connect(holder).setUser(TOKEN_ID, renter.address, expires);
          
            // pay rent for 1 USDC
            await usdc.connect(renter).approve(tomaasNFT.address, ONE_USDC);
            await tomaasNFT.connect(renter).payOutEarnings(TOKEN_ID, ONE_USDC);
            
            // claim earnings for holder
            const holderBalanceBefore = await usdc.balanceOf(holder.address);
            const ownerBalanceBefore = await usdc.balanceOf(owner.address);
            const receipt = await tomaasNFT.connect(holder).claimEarnings(TOKEN_ID);
            const holderBalanceAfter = await usdc.balanceOf(holder.address);
            const ownerBalanceAfter = await usdc.balanceOf(owner.address);
            
            // check that the earnings were distributed correctly
            const feeRate = await tomaasNFT.getFeeRate();
            const expectedFee = ethers.utils.parseUnits("0.01", 6); // 1% fee
            const expectedAmountToOwner = expectedFee;
            const expectedAmountToHolder = ethers.utils.parseUnits("0.99", 6);
            expect(holderBalanceAfter.sub(holderBalanceBefore)).to.equal(expectedAmountToHolder);
            expect(ownerBalanceAfter.sub(ownerBalanceBefore)).to.equal(expectedAmountToOwner);
          });

          it("should allow multiple users to rent the same NFT and distribute earnings correctly", async () => {
          });
    });

    describe("stress test", () => {
        it("should handle multiple users renting the same NFT", async function() {
        });
        it("handles a large number of NFTs and users without performance issues", async () => {
        });
    });
});