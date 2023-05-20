const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

require('dotenv').config();

describe("TomaaS Staking Pool", () => {

    let deployerAddress;
    let clientAddress;
    
    const nullAddress = "0x0000000000000000000000000000000000000000";
    const UsdcAddress = process.env.USDC_ETH_ADDRESS;
    const USDC_UNIT = ethers.utils.parseUnits("1000", 6).mul(1000000);

    let lpnContract;
    let rwnContract;
    let erc20MockContract;
    let stakingPoolContract;

    const tokenUri = "https://ipfs.io/ipfs/Qm...";

    before("deploy associated contracts", async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();
        deployerAddress = deployerSigner.address;
        clientAddress = clientSigner.address;

        // ERC20 Contract
        const erc20MockContractFactory = await ethers.getContractFactory("ERC20Mock");
        erc20MockContract = await upgrades.deployProxy(erc20MockContractFactory, ["USD Coin", "USDC"], {
            initializer: "initialize",
        });
        await erc20MockContract.deployed();
        console.log(`Address of ERC20 Mock Contract: ${erc20MockContract.address}`);

        await erc20MockContract.connect(deployerSigner).mint(deployerAddress, USDC_UNIT);
        await erc20MockContract.connect(deployerSigner).mint(clientAddress, USDC_UNIT);
        console.log(`balance of provider : ${await erc20MockContract.balanceOf(deployerAddress)}`);
        console.log(`balance of client : ${await erc20MockContract.balanceOf(clientAddress)}`);

        // LPN Contract
        const lpnContractFactory = await ethers.getContractFactory("TomaasLPN");
        lpnContract = await upgrades.deployProxy(lpnContractFactory, [
            erc20MockContract.address,
            ethers.utils.parseUnits("100", 6).mul(1000000)
        ], {
            initializer: "initialize",
        });
        await lpnContract.deployed();
        console.log(`Address of LPN Contract: ${lpnContract.address}`);

    });

    it("deploy and initialize tomaas-staking-pool-contract", async () => {
        const stakingPoolContractFactory = await ethers.getContractFactory("TomaasStakingPool");
        stakingPoolContract = await upgrades.deployProxy(stakingPoolContractFactory, [
            lpnContract.address, 
            erc20MockContract.address
        ], {
            initializer: "initialize",
        });
        await stakingPoolContract.deployed();
        console.log(`Address of Staking Pool Contract: ${stakingPoolContract.address}`);

        // initialize Staking and set TokensClaimable true
        await stakingPoolContract.initStaking();
        await stakingPoolContract.setRewardsClaimable(true);
        console.log("StakingSystemContract is initialized");
    });

    it("set approval and mint nfts", async () => {
        // set Approval For All in the NFT Contract to the Staking Pool Contract
        const [deployerSigner, clientSigner] = await ethers.getSigners();

        await erc20MockContract.connect(deployerSigner).approve(
            lpnContract.address,
            ethers.utils.parseUnits("500", 6).mul(6000000)
        );

        await expect(
            lpnContract.setApprovalForAll(stakingPoolContract.address, true)
        )
            .to.emit(lpnContract, "ApprovalForAll")
            .withArgs(deployerAddress, stakingPoolContract.address, true);

        await lpnContract.safeMint_mul(clientAddress, tokenUri, 6);
    });

    it("stake a nft", async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();

        await expect(
            lpnContract.connect(clientSigner).setApprovalForAll(
                stakingPoolContract.address,
                true
            )
        )
            .to.emit(lpnContract, "ApprovalForAll")
            .withArgs(clientAddress, stakingPoolContract.address, true);
        
        await expect(stakingPoolContract.connect(clientSigner).stakeToken(0))
            .to.emit(stakingPoolContract, "Staked")
            .withArgs(clientAddress, 0);
        console.log(`token id 0 is staked!`);
    });

    it("stake nfts", async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();

        await expect(
            lpnContract.connect(clientSigner).setApprovalForAll(
                stakingPoolContract.address,
                true
            )
        )
            .to.emit(lpnContract, "ApprovalForAll")
            .withArgs(clientAddress, stakingPoolContract.address, true);
        
        await expect(stakingPoolContract.connect(clientSigner).stakeTokens([1,2]))
            .to.emit(stakingPoolContract, "Staked")
            .withArgs(clientAddress, 2);
        console.log(`token id 1,2 is staked!`);
    });

    it("get staked nfts", async () => {
        const stakedTokens = await stakingPoolContract.getStakedTokens(clientAddress);
        console.log(`staked token ids : ${stakedTokens.toString()}`);

        const ownerOfToken0 = await lpnContract.ownerOf(0);
        const ownerOfToken1 = await lpnContract.ownerOf(1);
        const ownerOfToken2 = await lpnContract.ownerOf(2);

        expect(
            clientAddress == ownerOfToken0
            &&
            clientAddress == ownerOfToken1
            &&
            clientAddress == ownerOfToken2,
            true
        )
        
        console.log(`the Staking Pool address : ${stakingPoolContract.address}`);
        console.log(`the owner of token id 0: ${ownerOfToken0}`);
        console.log(`the owner of token id 1: ${ownerOfToken1}`);
        console.log(`the owner of token id 2: ${ownerOfToken2}`);
    });

    it("unstake a nft", async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();

        await expect(stakingPoolContract.connect(clientSigner).unstakeToken(2))
            .to.emit(stakingPoolContract, "Unstaked")
            .withArgs(clientAddress, 2);
        console.log(`token id 2 is unstaked!`);

        // const stakedTokens = await stakingPoolContract.getStakedTokens(clientAddress);
        // console.log(`staked token ids : ${stakedTokens.toString()}`);

        // check the owner of the token is client address.
        const ownerAddress = await lpnContract.ownerOf(2);
        expect(
            clientAddress == ownerAddress,
            true
        )
        console.log(`the client address : ${clientAddress}`);
        console.log(`the owner of token id 2 : ${ownerAddress}`);

        const stakedTokenIds = await stakingPoolContract.getStakedTokens(clientAddress);
        console.log(`staked token ids : ${stakedTokenIds.toString()}`);
    });

    it("unstake nfts", async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();

        await expect(stakingPoolContract.connect(clientSigner).unstakeTokens([0,1]))
            .to.emit(stakingPoolContract, "Unstaked")
            .withArgs(clientAddress, 1);
        console.log(`token id 0,1 are unstaked`);

        const ownerOfToken0 = await lpnContract.ownerOf(0);
        const ownerOfToken1 = await lpnContract.ownerOf(1);
        expect(
            clientAddress == ownerOfToken0
            &&
            clientAddress == ownerOfToken1,
            true
        )
        console.log(`the client address : ${clientAddress}`);
        console.log(`the owner of token id 0: ${ownerOfToken0}`);
        console.log(`the owner of token id 1: ${ownerOfToken1}`);
    });

    it("unstake all nfts", async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();

        await expect(stakingPoolContract.connect(clientSigner).stakeTokens([3,4,5]))
            .to.emit(stakingPoolContract, "Staked")
            .withArgs(clientAddress, 5);

        await expect(
            stakingPoolContract.getStakedTokens() == [3,4,5],
            true
        );
        console.log(`token id 3,4,5 are staked!`);
        console.log(`the owner of Token id 5 : ${await lpnContract.ownerOf(5)}`);

        await stakingPoolContract.connect(clientSigner).unstakeAllTokens();
        const ownerOfToken3 = await lpnContract.ownerOf(3);
        const ownerOfToken4 = await lpnContract.ownerOf(4);
        const ownerOfToken5 = await lpnContract.ownerOf(5);
    
        expect(
            clientAddress === ownerOfToken3
            &&
            clientAddress === ownerOfToken4
            &&
            clientAddress === ownerOfToken5,
            true
        );

        console.log(`the client address : ${clientAddress}`);
        console.log(`the owner of token id 3: ${ownerOfToken3}`);
        console.log(`the owner of token id 4: ${ownerOfToken4}`);
        console.log(`the owner of token id 5: ${ownerOfToken5}`);

    });
});