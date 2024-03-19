# Sample Hardhat Project

This is the Repository for the EVOX Smart contracts:

Its has 3 choices of deployment environments:

1. hardhat 
2. zkevm
3. mumbai testnet

You can deploy to any network you choose by adding the --network flag to you deployment command, 
if you do not it will default to hardhat.


There are multiple signers for the network you choose. 

The main files are:

1. datahub.sol
    - This contract holds all stateful data for the contracts, and base functions to manipulate that data
2. executor.sol
    - This contract is responsible for receiving a trade, querying the oracle, receiving its repsonse, and acting upon the order        confirmation
3. interestData.sol
    - This contract is responsible for holding interest Rate data, and calculating interest charges
4. utils.sol
    - This contract is reponsible for doing various utility functions related to the executor.
5. depositvault.sol
    - This contract holds all deposits, and issues deposits, and withdraws 
6. liquidator.sol
    - This contract is reposible for handling liquidations of liquidatable accounts



You May run the following commands in this repo

Compile:
npm run compile

Deploy --hardhat:

Deploy --zkevm:

Deploy --mumbai: 


```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.js
```

FOR GAS ESTIMATION ON TX:

// transaction-retry-tool
//hardhat-gas-trackooor

hardhat-insight
Andres Adjimann
Hardhat plugin to get contract storage, gas and code size insights using the compiler ast output


FOR DOCS:
@bonadocs/docgen


FOR TESTS:

@mangrovedao/hardhat-test-solidity
Mangrove
Hardhat plugin for writing tests in solidity

Get metrics on the gas used by your contracts with the hardhat-gas-reporter plugin. https://github.com/cgewecke/hardhat-gas-reporter
FOR AUX:

@graphprotocol/hardhat-graph
The Graph
Develop your subgraph side by side with your contracts to save gas and increase productivity.