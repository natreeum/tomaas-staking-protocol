const hre = require("hardhat");

require('dotenv').config();
const path = require("path");

async function main() {
  if (network.name === "hardhat") {
    console.warn(
      "You are trying to deploy a contract to the Hardhat Network, which" +
        "gets automatically created and destroyed every time. Use the Hardhat" +
        " option '--network localhost'"
    );
  }

  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  //deploy USDC for tomaas testing
  const USDC = await hre.ethers.getContractFactory("ERC20Mock");
  let usdc = await upgrades.deployProxy(USDC, ["USD Coin", "USDC"]);
  await usdc.deployed();
  console.log("USDC address:", usdc.address);

  const FLO_SSD = new Date("2020-11-20").getTime();
  const FLO_USEFUL_LIFE = 4;
  const FLO_PRICE = 770;
  const FLO_RWA_AMOUNT = 1600;

  const TomaasRWN = await hre.ethers.getContractFactory("TomaasRWN");

  const COLLECTION_NAME_1 = "TRN FLO #1";

  const TRN_FLO_1 = await upgrades.deployProxy(TomaasRWN, 
                              [ COLLECTION_NAME_1, 
                                usdc.address, 
                                FLO_SSD, 
                                FLO_USEFUL_LIFE, 
                                FLO_PRICE]);
  await TRN_FLO_1.deployed();
  console.log("TRN FLO #1 address:", TRN_FLO_1.address);

  const TomaasProtocol = await hre.ethers.getContractFactory("TomaasProtocol");
  const tomaasProtocol = await upgrades.deployProxy(TomaasProtocol);
  await tomaasProtocol.deployed();
  console.log("TomaasProtocol address:", tomaasProtocol.address);

  await TRN_FLO_1.transferOwnership(tomaasProtocol.address);
  await tomaasProtocol.addCollection(TRN_FLO_1.address);

  const TomaasMarketplace = await hre.ethers.getContractFactory("TomaasMarketplace");
  const tomaasMarketplace = await upgrades.deployProxy(TomaasMarketplace, [tomaasProtocol.address]);
  await tomaasMarketplace.deployed();
  console.log("TomaasMarketplace address:", tomaasMarketplace.address);

  const TomaasLPN = await hre.ethers.getContractFactory("TomaasLPN");
  const tomaasLPN = await upgrades.deployProxy(TomaasLPN, [usdc.address, 100]);
  await tomaasLPN.deployed();
  console.log("TomaasLPN address:", tomaasLPN.address);

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
