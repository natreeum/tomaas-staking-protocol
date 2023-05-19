const { expect } = require("chai");
const { ethers } = require("hardhat");

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

    before("deploy associated contracts",async () => {
        const [deployerSigner, clientSigner] = await ethers.getSigners();
        deployerAddress = deployerSigner.address;
        clientAddress = clientSigner.address;

        const lpnContractFactory = await ethers.getContractFactory("TomaasLPN");
        lpnContract = await lpnContractFactory.deploy();
        await lpnContract.deployed();
        console.log(`Address of LPN Contract: ${lpnContract.address}`);
        
        const rwnContractFactory = await ethers.getContractFactory("TomaasRWN");
        rwnContract = await rwnContractFactory.deploy();
        await rwnContract.deployed();
        console.log(`Address of RWN Contract: ${rwnContract.address}`)

        const erc20MockContractFactory = await ethers.getContractFactory("ERC20Mock");
        erc20MockContract = await erc20MockContractFactory.deploy();
        await erc20MockContract.deployed();
        console.log(`Address of ERC20 Mock Contract: ${erc20MockContract.address}`)

    });

    it("deploy and initialize tomaas-staking-pool-contract", async () => {
        const stakingPoolContractFactory = await ethers.getContractFactory("TomaasStakingPool");
        stakingPoolContract = await stakingPoolContractFactory.deploy(
            lpnContract.address,
            erc20MockContract.address
        );
        await stakingPoolContract.deployed();

        console.log(`Address of Staking Pool Contract: ${stakingPoolContract.address}`);

        // initialize Staking and set TokensClaimable true
        // await stakingPoolContract.initStaking();
        // await stakingPoolContract.setTokenClaimable(true);
        // console.log("StakingSystemContract is initialized");
    })
});