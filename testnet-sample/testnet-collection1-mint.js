const Bundlr = require("@bundlr-network/client");
const fs = require("fs");
require('dotenv').config();
const path = require("path");

const hre = require("hardhat");
// Change this line to match the name of the wallet key file
// you downloaded from https://faucet.arweave.net/.
// Physically move your key file from the download directory to the
// project directory that holds this JS file.
const privateKey = "./arweave-keyfile.json";

const jwk = JSON.parse(fs.readFileSync(privateKey).toString());

// NOTE: Depending on the version of JavaScript you use, you may need to use
// the commented out line below to create a new Bundlr object.
// const bundlr = new Bundlr("http://node1.bundlr.network", "arweave", jwk);
const bundlr = new Bundlr.default("http://node2.bundlr.network", "arweave", jwk);

// Print your wallet address
console.log(`wallet address = ${bundlr.address}`);

let tomaasNFT;
let tomaasProtocol;
let deployerAddr;

function loadContractsFile() {
  const fs = require("fs");
  const contractsDir = path.join(__dirname, "../frontend/contracts");
  
  var data = fs.readFileSync(path.join(contractsDir, "contract-address.json"));
  var jsonData = JSON.parse(data);
  console.log(jsonData);
  return jsonData;
} 

// load contract address
async function loadContract() {
  const [deployer] = await ethers.getSigners();
  deployerAddr = await deployer.getAddress();

  console.log( "Deploying the contracts with the account:", deployerAddr );
  const constractAddresses = loadContractsFile();

  console.log( "TomaasNFT:", constractAddresses.TomaasNFT, 
    "TomaasProtocol:", constractAddresses.TomaasProtocol, 
    "TomaasMarketplace:", constractAddresses.TomaasMarketplace );

  const TomaasNFT = await hre.ethers.getContractFactory("TomaasNFT");
  tomaasNFT = await TomaasNFT.attach(constractAddresses.TomaasNFT);

  const TomaasProtocol = await hre.ethers.getContractFactory("TomaasProtocol");
  tomaasProtocol = await TomaasProtocol.attach(constractAddresses.TomaasProtocol);
}

// Skip upload image file

function loadNFTImageFile() {
  const nftImgList = JSON.parse(fs.readFileSync("./testnet-sample/nft-img-list.json").toString());
  return nftImgList[0];
}

// Upload metadata data
async function main() {

  loadContract();

  let metadata = JSON.parse(fs.readFileSync("./testnet-sample/tomaas-nft.json").toString());
  let nftImgList = loadNFTImageFile();
  let name = metadata.name;
  metadata.image = nftImgList.collectionImg;

  for (let i = 0; i < 10; i++) {
    metadata.name = name + " #" + i;
    try {
      console.log(metadata);
      // bunlder sdk has bug, so use fs.writeFileSync and upload file
      // let response = await bundlr.upload(JSON.stringify(metadata, null, 2));
      
      let fileName = `tomaas-collection1-nft${i}.json` 
      fs.writeFileSync("./testnet-sample/"+fileName, JSON.stringify(metadata, null, 2));
      let response = await bundlr.uploadFile("./testnet-sample/"+fileName);
      
      let tokenURI = "https://arweave.net/" + response.id;
      console.log(`Metadata uploaded ==> ${tokenURI}`);
      await tomaasProtocol.safeMintNFT(tomaasNFT.address, deployerAddr, tokenURI);
    }
    catch (e) {
      console.log("Error uploading file ", e);
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
