require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require('hardhat-abi-exporter');
require('hardhat-gui');
require('hardhat-deploy');
require("@solarity/hardhat-markup")
//https://www.npmjs.com/package/hardhat-abi-exporter
/** @type import('hardhat/config').HardhatUserConfig */

const PRIVATE_KEY = "95df27c34905b67b60c535cea898f4560576a016a1e53d234e07896d6c63c3cb"

const TAKERPK =  "e02704e8da196d935f8155d193a07a769ee126e0dd25b5adbd73f1f9e7dd7ec8"


const MAKERPK = "c58f4e631d9c80ac977fc9d1b51c6ba7600eb35129b7b6658e3932dd05aa51de"


module.exports = {
  solidity: "0.8.20",
  defaultNetwork: "hardhat",

  paths: {
    sources: "./contracts", // The directory where your contracts are located
    artifacts: "./artifacts", // The directory where artifact files will be generated
    tests: "./test",
  },
  logging: {
    enabled: true,

  },
  markup: {
    outdir: "./generated-markups",
    onlyFiles: ["./contracts/utils.sol"],
    skipFiles: [],
    noCompile: false,
    verbose: false,
  },
  networks: {
    hardhat: {
      allowBlocksWithSameTimestamp: true,
      accounts: [
        { privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', balance: '1000000000000000000000' },
        { privateKey: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', balance: '1000000000000000000000' },
        // ... other accounts
      ],
    },
    mumbai: {
      url: `https://polygon-mumbai.g.alchemy.com/v2/ebPip_MjwdmPr5ZGZfua4SgAjSwEELvw`,
      accounts: [PRIVATE_KEY,TAKERPK,MAKERPK],
      gasPrice: 50000000000,
      blockGasLimit: 100000000429720 // whatever you want here,

    },

    zkevm: {
      url: `https://rpc.cardona.zkevm-rpc.com/`,
      accounts: [MAKERPK,TAKERPK],
      gasPrice: 5000000000,
      blockGasLimit: "100000000042972000000" // whatever you want here,

    },
  },
};
