// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

require('dotenv').config();
const path = require("path");

async function main() {
  // This is just a convenience check
  if (network.name === "hardhat") {
    console.warn(
      "You are trying to deploy a contract to the Hardhat Network, which" +
        "gets automatically created and destroyed every time. Use the Hardhat" +
        " option '--network localhost'"
    );
  }

  // ethers is available in the global scope
  const [deployer] = await ethers.getSigners();
  console.log(
    "Deploying the contracts with the account:",
    await deployer.getAddress()
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const COLLECTION_NAME_1 = "TomaasRWN #1";

  const TomaasRWN = await hre.ethers.getContractFactory("TomaasRWN");
  const tomaasRWN = await TomaasRWN.deploy(COLLECTION_NAME_1, process.env.USDC_ETH_ADDRESS);
  await tomaasRWN.deployed();
  console.log("TomaasRWN address:", tomaasRWN.address);

  const TomaasProtocol = await hre.ethers.getContractFactory("TomaasProtocol");
  const tomaasProtocol = await TomaasProtocol.deploy();
  await tomaasProtocol.deployed();
  console.log("TomaasProtocol address:", tomaasProtocol.address);

  await tomaasRWN.transferOwnership(tomaasProtocol.address);
  await tomaasProtocol.addCollection(tomaasRWN.address);

  const TomaasMarketplace = await hre.ethers.getContractFactory("TomaasMarketplace");
  const tomaasMarketplace = await TomaasMarketplace.deploy(tomaasProtocol.address);
  await tomaasMarketplace.deployed();
  console.log("TomaasMarketplace address:", tomaasMarketplace.address);

  // We also save the contract's artifacts and address in the frontend directory
  saveFrontendFiles(tomaasRWN, tomaasProtocol, tomaasMarketplace); 
}

function saveFrontendFiles(tomaasRWN, tomaasProtocol, tomaasMarketplace) {
  const fs = require("fs");
  const contractsDir = path.join(__dirname, "../frontend/contracts");

  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir);
  }

  fs.writeFileSync(
    path.join(contractsDir, "contract-address.json"),
    JSON.stringify({ 
      TomaasRWN: tomaasRWN.address, 
      TomaasProtocol: tomaasProtocol.address, 
      TomaasMarketplace: tomaasMarketplace.address
    }, undefined, 2));

  const TomaasNFArtifact = artifacts.readArtifactSync("TomaasRWN");
  fs.writeFileSync(
    path.join(contractsDir, "TomaasRWN.json"),
    JSON.stringify(TomaasNFArtifact, null, 2)
  );

  const TomaasProtocolArtifact = artifacts.readArtifactSync("TomaasProtocol");
  fs.writeFileSync(
    path.join(contractsDir, "TomaasProtocol.json"),
    JSON.stringify(TomaasProtocolArtifact, null, 2)
  );

  const TomaasMarketplaceArtifact = artifacts.readArtifactSync("TomaasMarketplace");
  fs.writeFileSync(
    path.join(contractsDir, "TomaasMarketplace.json"),
    JSON.stringify(TomaasMarketplaceArtifact, null, 2)
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
