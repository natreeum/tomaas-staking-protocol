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

  const TomaasRWN = await hre.ethers.getContractFactory("TomaasRWN");

  const COLLECTION_NAME_1 = "Tomaas Real World Asset NFT MAX #1";

  const MAX_SSD = new Date("2020.5.10").getTime();
  const MAX_USEFUL_LIFE = 4;
  const MAX_PRICE = 660;

  const MAXPRO_SSD = new Date("2020.12.2").getTime();
  const MAXPRO_USEFUL_LIFE = 4;
  const MAXPRO_PRICE = 770;

  const MAXPLUS_SSD = new Date("2021.5.25").getTime();
  const MAXPLUS_USEFUL_LIFE = 4;
  const MAXPLUS_PRICE = 880;

  const TRN_MAX_1 = await upgrades.deployProxy(TomaasRWN, 
                              [ COLLECTION_NAME_1, 
                                usdc.address, 
                                MAX_SSD, 
                                MAX_USEFUL_LIFE, 
                                MAX_PRICE]);
  await TRN_MAX_1.deployed();
  console.log("TRN MAX #1 address:", TRN_MAX_1.address);

  const COLLECTION_NAME_2 = "Tomaas Real World Asset NFT MAX Pro #1";
  const TRN_MAXPro_1 = await upgrades.deployProxy(TomaasRWN, 
                              [ COLLECTION_NAME_2, 
                                usdc.address,
                                MAXPRO_SSD,
                                MAXPRO_USEFUL_LIFE,
                                MAXPRO_PRICE]);
  await TRN_MAXPro_1.deployed();
  console.log("TRN MAX Pro #1 address:", TRN_MAXPro_1.address);

  const COLLECTION_NAME_3 = "Tomaas Real World Asset NFT MAX Plus #1";
  const TRN_MAXPlus_1 = await upgrades.deployProxy(TomaasRWN, 
                              [ COLLECTION_NAME_3, 
                                usdc.address,
                                MAXPLUS_SSD,
                                MAXPLUS_USEFUL_LIFE,
                                MAXPLUS_PRICE]);
  await TRN_MAXPlus_1.deployed();
  console.log("TRN MAX Plus #1 address:", TRN_MAXPlus_1.address);

  const TomaasProtocol = await hre.ethers.getContractFactory("TomaasProtocol");
  const tomaasProtocol = await upgrades.deployProxy(TomaasProtocol);
  await tomaasProtocol.deployed();
  console.log("TomaasProtocol address:", tomaasProtocol.address);

  await TRN_MAX_1.transferOwnership(tomaasProtocol.address);
  await tomaasProtocol.addCollection(TRN_MAX_1.address);

  await TRN_MAXPro_1.transferOwnership(tomaasProtocol.address);
  await tomaasProtocol.addCollection(TRN_MAXPro_1.address);

  await TRN_MAXPlus_1.transferOwnership(tomaasProtocol.address);
  await tomaasProtocol.addCollection(TRN_MAXPlus_1.address);

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
