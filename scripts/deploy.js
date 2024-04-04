
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

  const gasLimit = 30000000; // Specify your desired gas limit here


  const EVO_LIB = await hre.ethers.deployContract("EVO_LIBRARY");

  await EVO_LIB.waitForDeployment();

  console.log("EVO Library deployed to", await EVO_LIB.getAddress());

  const Deploy_dataHub = await hre.ethers.deployContract("DataHub", [initialOwner, executor, depositvault, oracle, initialOwner, initialOwner],  {
    gasLimit: gasLimit
  }
);

  await Deploy_dataHub.waitForDeployment();

  console.log("Datahub deployed to", await Deploy_dataHub.getAddress());


  const Interest = await hre.ethers.getContractFactory("interestData", {
    libraries: {
      EVO_LIBRARY: await EVO_LIB.getAddress(),
    },
  });

  const Deploy_interest = await Interest.deploy(initialOwner, executor, depositvault, initialOwner, initialOwner);


  await Deploy_interest.waitForDeployment();

  console.log("Interest deployed to", await Deploy_interest.getAddress());



  const depositVault = await hre.ethers.getContractFactory("DepositVault", {
    libraries: {
      EVO_LIBRARY: await EVO_LIB.getAddress(),
    },
  });
  const Deploy_depositVault = await depositVault.deploy(initialOwner, await Deploy_dataHub.getAddress(), initialOwner, await Deploy_interest.getAddress());

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
      EVO_LIBRARY: await EVO_LIB.getAddress(),
    },
  });
  const Deploy_Utilities = await Utility.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), initialOwner, await Deploy_interest.getAddress());

  console.log("Utils deployed to", await Deploy_Utilities.getAddress());

  const Liquidator = await hre.ethers.getContractFactory("Liquidator", {
    libraries: {
      EVO_LIBRARY: await EVO_LIB.getAddress(),
    },
  });
  const Deploy_Liquidator = await Liquidator.deploy(initialOwner, Deploy_dataHub.getAddress(), initialOwner); // need to alter the ex after 

  console.log("Liquidator deployed to", await Deploy_Liquidator.getAddress());

  const Exchange = await hre.ethers.getContractFactory("EVO_EXCHANGE", {
    libraries: {
      EVO_LIBRARY: await EVO_LIB.getAddress(),
    },
  });


  const Deploy_Exchange = await Exchange.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), Deploy_Utilities.getAddress(), await Deploy_interest.getAddress(), Deploy_Liquidator.getAddress());

  console.log("Exchange deployed to", await Deploy_Exchange.getAddress());

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });