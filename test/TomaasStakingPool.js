const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

require('dotenv').config();

describe("TomaaS Staking Pool", () => {

    let deployerAddress;
    let clientAddress;
    
    const nullAddress = "0x0000000000000000000000000000000000000000";
    const UsdcAddress = process.env.USDC_ETH_ADDRESS;

    let lpnContract;
    let rwnContract;
    let erc20MockContract;
    let stakingPoolContract;

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

        // LPN Contract
        const lpnContractFactory = await ethers.getContractFactory("TomaasLPN");
        lpnContract = await upgrades.deployProxy(lpnContractFactory, [], {
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

    it("set Approval and Mint NFT", async () => {
        // set Approval For All in the NFT Contract to the Staking Pool Contract
        console.log((stakingPoolContract.address, clientAddress, 0));
        await expect(
            lpnContract.setApprovalForAll(stakingPoolContract.address, true)
        )
            .to.emit(lpnContract, "ApprovalForAll")
            .withArgs(deployerAddress, stakingPoolContract.address, true);
    });
});