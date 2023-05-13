# Trustless ondemand sharing mobility as a Service 

TomaaS is to create a democratized, sustainable, and transparent mobility ecosystem that harnesses blockchain technology and community collaboration to deliver accessible, innovative, and user-centric services for all participants. By enabling individuals and communities to actively participate in the ownership and provision of mobility services, TomaaS aims to break down barriers to entry and foster a more inclusive ecosystem.

You need to set .env for setting

```
USDC_ETH_ADDRESS = ""
REACT_APP_ALCHEMY_API_URL=""
REACT_APP_PRIVATE_KEY=""
```

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```
How to release to testnet
```shell
npx hardhat run scripts/deploy.js --network goerli
npx hardhat run testnet-sample/testnet-collection1-mint.js --network goerli
npx hardhat run testnet-sample/testnet-collection2-mint.js --network goerli
npx hardhat run testnet-sample/testnet-collection3-mint.js --network goerli
```
