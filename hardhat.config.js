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
  defaultNetwork: "zkevm",

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

    zkevm: {
      url: `https://rpc.cardona.zkevm-rpc.com/`,
      accounts: [MAKERPK,TAKERPK],
      gasPrice: 5000000000,
      blockGasLimit: "100000000042972000000" // whatever you want here,

    },
  },
};
