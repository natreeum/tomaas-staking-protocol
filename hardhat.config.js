require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();
require('@openzeppelin/hardhat-upgrades');

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 1337
    },
    goerli: {
      url: 
        process.env.REACT_APP_ALCHEMY_API_URL !== undefined ? process.env.REACT_APP_ALCHEMY_API_URL : "",
      accounts: 
        process.env.REACT_APP_PRIVATE_KEY !== undefined ? [process.env.REACT_APP_PRIVATE_KEY] : [],
    },
    localnet: {
      url: // .env file -> LOCAL_HARDHAT_NODE=http://127.0.0.1:8545 
        process.env.LOCAL_HARDHAT_NODE !== undefined ? process.env.LOCAL_HARDHAT_NODE : "",
      accounts:
        process.env.LOCAL_PRIVATE_KEY !== undefined ? [process.env.LOCAL_PRIVATE_KEY] : [],
      chainId: 1337,
    },                        
    zkevm: {
      url: // .env file -> ZKEVM_TESTNET_NODE=https://rpc.public.zkevm-test.net
        process.env.ZKEVM_TESTNET_NODE !== undefined ? process.env.ZKEVM_TESTNET_NODE : "",
      accounts: 
        process.env.ZKEVM_PRIVATE_KEY !== undefined ? [process.env.ZKEVM_PRIVATE_KEY] : [],
    }                  
  },           
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  }
};
