// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners(0);

  console.log("Deploying contracts with the account:", deployer.address, await deployer.balance);

  const initialOwner = deployer.address // insert wallet address 
  const airnodeRRPAddress = "0x9499A917cF8ca139C0E06F9728E1C6A0f7a1f5F2" // insert airnode address , address _executor, address _deposit_vault
  const executor = initialOwner;
  const depositvault = initialOwner;
  const oracle = initialOwner;
  // Deploy REXE library

  console.log("Deploying contracts with the account:", deployer.address);


  // Deploy REXE library

  const REX_LIB = await hre.ethers.deployContract("REX_LIBRARY");

  await REX_LIB.waitForDeployment();

  console.log("REX Library deployed to", await REX_LIB.getAddress());

  const Interest = await hre.ethers.getContractFactory("interestData", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });

  const Deploy_interest = await Interest.deploy(initialOwner, executor, depositvault);

  await Deploy_interest.waitForDeployment();

  console.log("Interest deployed to", await Deploy_interest.getAddress());


  const Deploy_dataHub = await hre.ethers.deployContract("DataHub", [initialOwner, executor, depositvault, oracle, Deploy_interest.getAddress()]);

  ///const Deploy_dataHub = await DATAHUB.deploy(initialOwner, executor, depositvault, oracle);

  await Deploy_dataHub.waitForDeployment();

  console.log("Datahub deployed to", await Deploy_dataHub.getAddress());

  const depositVault = await hre.ethers.getContractFactory("DepositVault", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });

  const Deploy_depositVault = await depositVault.deploy(initialOwner, Deploy_dataHub.getAddress(), initialOwner, Deploy_interest.getAddress());

  await Deploy_depositVault.waitForDeployment();

  console.log("Deposit Vault deployed to", await Deploy_depositVault.getAddress());



  const DeployOracle = await hre.ethers.deployContract("Oracle", 
  [initialOwner,
    Deploy_dataHub.getAddress(),
    Deploy_depositVault.getAddress(),
    airnodeRRPAddress,
    initialOwner])
  // chnage ex
  console.log("Oracle deployed to", await DeployOracle.getAddress());

  const Utility = await hre.ethers.getContractFactory("Utility", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });
  const Deploy_Utilities = await Utility.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), initialOwner, Deploy_interest.getAddress());

  console.log("Utils deployed to", await Deploy_Utilities.getAddress());

  const Exchange = await hre.ethers.getContractFactory("REX_EXCHANGE", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });

  const Liquidator = await hre.ethers.getContractFactory("Liquidator", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });
  const Deploy_Liquidator = await Liquidator.deploy(initialOwner, Deploy_dataHub.getAddress(), initialOwner); // need to alter the ex after 

  console.log("Liquidator deployed to", await Deploy_Liquidator.getAddress());

  const Deploy_Exchange = await Exchange.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), Deploy_Utilities.getAddress(),await Deploy_interest.getAddress(),Deploy_Liquidator.getAddress());
  
  console.log("Exchange deployed to", await Deploy_Exchange.getAddress());


}
//npx hardhat run scripts/deploy.js --network mumbai
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
