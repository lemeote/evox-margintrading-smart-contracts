require("@nomicfoundation/hardhat-toolbox");
require("hardhat-gas-reporter");
require('hardhat-abi-exporter');
require('hardhat-gui');
require('hardhat-deploy');
require("@solarity/hardhat-markup")
require("hardhat-contract-sizer");
//https://www.npmjs.com/package/hardhat-abi-exporter
/** @type import('hardhat/config').HardhatUserConfig */


module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  contractSizer: {
    alphaSort: true,
    disambiguatePaths: false,
    runOnCompile: true,
    strict: false,
    unit: "KiB",

  },
  defaultNetwork: "hardhat",
  mocha: {
    timeout: 100000000
  },
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
      forking: {         
        url: "https://rpc.ankr.com/polygon_zkevm_cardona",  // you must change this id    
      },
      chainId: 2442,
      forking: {
        // Using Alchemy
        url: "https://rpc.ankr.com/polygon_zkevm_cardona", // url to RPC node, ${ALCHEMY_KEY} - must be your API key
        // Using Infura
        // url: `https://mainnet.infura.io/v3/${INFURA_KEY}`, // ${INFURA_KEY} - must be your API key
        blockNumber: 2966185, // a specific block number with which you want to work
      },     
      accounts: [
        { privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', balance: '1000000000000000000000' },
        { privateKey: '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d', balance: '1000000000000000000000' },
        // ... other accounts
      ],
    },
  },
  allowUnlimitedContractSize: true,
};
