// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");
const tokenabi = require("./token_abi.json");
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
// interest needs datahub and executor 

// datahub,deposit, exec need the interest --> its the last item int he array so deploy it then alter the admin roles after you havve dh and ex
async function main() {
  const [deployer] = await hre.ethers.getSigners(0);

  console.log("Deploying contracts with the account:", deployer.address);

  const initialOwner = deployer.address // insert wallet address 
  // insert airnode address , address _executor, address _deposit_vault
  const executor = initialOwner;
  const depositvault = initialOwner;
  const oracle = initialOwner;
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


  const DeployOracle = await hre.ethers.deployContract("Oracle", [initialOwner,
    Deploy_dataHub.getAddress(),
    Deploy_depositVault.getAddress(),
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


  const Deploy_Exchange = await Exchange.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), Deploy_Utilities.getAddress(), Deploy_interest.getAddress());

  console.log("Exchange deployed to", await Deploy_Exchange.getAddress());


  const REXE = await hre.ethers.deployContract("REXE", [deployer.address]);

  await REXE.waitForDeployment();

  console.log("REXE deployed to", await REXE.getAddress());

  const USDT = await hre.ethers.deployContract("USDT", [deployer.address]);


  await USDT.waitForDeployment();

  console.log("USDT deployed to", await USDT.getAddress());

  await init(await USDT.getAddress(), await REXE.getAddress(), await Deploy_Exchange.getAddress(), await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress(), await DeployOracle.getAddress(), await Deploy_Utilities.getAddress(), await Deploy_interest.getAddress())

  await deposit(await Deploy_depositVault.getAddress(), await USDT.getAddress(), await REXE.getAddress())
}
//npx hardhat run scripts/deploy.js 
main().then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });


async function deposit(DV, USDT, REXE) {

  const depositvault = DV
  const taker = await hre.ethers.provider.getSigner(1); // deposit usdt  // 0x8d23Bd68E5c095B7A1999E090B2F9c20114CbBb4

  const contractABI = tokenabi.abi; // token abi for approvals 
  const deposit_amount = "100000000000000000000"

  const TOKENCONTRACT = new hre.ethers.Contract(USDT, contractABI, taker);
  // Wait for approval transaction to finish
  const approvalTx = await TOKENCONTRACT.approve(depositvault, deposit_amount);
  await approvalTx.wait();  // Wait for the transaction to be mined


  console.log("Deposit with account:", taker.address);

  const DVault = new hre.ethers.Contract(depositvault, depositABI.abi, taker);

  DVault.deposit_token(
    USDT,
    deposit_amount
  )

  const maker = await hre.ethers.provider.getSigner(1); // deposit REXE 0x19E75eD87d138B18263AfE40f7C16E4a5ceCB585 

  const deposit_amount_2 = "100000000000000000000"

  const TOKENCONTRACT_2 = new hre.ethers.Contract(REXE, tokenabi.abi, maker);
  // Wait for approval transaction to finish
  const approvalTx_2 = await TOKENCONTRACT_2.approve(depositvault, deposit_amount_2);
  await approvalTx_2.wait();  // Wait for the transaction to be mined

  console.log("Deposit with account:", maker.address);

  const DVM = new hre.ethers.Contract(depositvault, depositABI.abi, maker);

  DVM.deposit_token(
    REXE,
    deposit_amount
  )


  /// 100 tokens each 



}


async function init(USDT, REXE, ex, DH, DV, oracle, util, _int) {

  const USDTprice = "1000000000000000000"

  const USDTinitialMarginFee = "5000000000000000" // 0.5% //0.05 (5*16)
  const USDTliquidationFee = "30000000000000000"//( 3**17) was 30
  const USDTinitialMarginRequirement = "200000000000000000"//( 2**18) was 200
  const USDTMaintenanceMarginRequirement = "100000000000000000" // .1 ( 10*17)
  const USDToptimalBorrowProportion = "700000000000000000"//( 7**18) was 700
  const USDTmaximumBorrowProportion = "1000000000000000000"//( 10**18) was 1000
  const USDTInterestRate = "5000000000000000"//( 5**16) was 5
  const USDT_interestRateInfo = ["5000000000000000", "150000000000000000", "1000000000000000000"] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000



  const REXEprice = "500000000000000000";

  const REXEinitialMarginFee = "10000000000000000";
  const REXEliquidationFee = "10000000000000000";
  const REXEinitialMarginRequirement = "500000000000000000"
  const REXEMaintenanceMarginRequirement = "250000000000000000"
  const REXEoptimalBorrowProportion = "700000000000000000"
  const REXEmaximumBorrowProportion = "1000000000000000000"
  const REXEInterestRate = "5000000000000000"
  const REXEinterestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]


  const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

  console.log("INIT with the account:", deployer.address);

  const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

  const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

  const utils = new hre.ethers.Contract(util, utilABI.abi, deployer);

  const SETUP = await utils.AlterExchange(ex);


  SETUP.wait()

  const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

  const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle, util, _int);

  SETUPEX.wait()


  const setup = await DataHub.AlterAdminRoles(DV, ex, oracle, _int);

  setup.wait();

  const oraclesetup = await Oracle.AlterExecutor(ex);

  oraclesetup.wait();

  const Interest = new hre.ethers.Contract(_int, InterestAbi.abi, deployer);


  const interestSetup = await Interest.AlterAdmins(ex, DH);

  interestSetup.wait();


  const InitRatesREXE = await Interest.initInterest(REXE, 1, USDT_interestRateInfo, USDTInterestRate)
  const InitRatesUSDT = await Interest.initInterest(USDT, 1, REXEinterestRateInfo, REXEInterestRate)

  InitRatesREXE.wait();
  InitRatesUSDT.wait();


  const USDT_init_transaction = await DataHub.InitTokenMarket(USDT, USDTprice, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);


  USDT_init_transaction.wait();


  const REXE_init_transaction = await DataHub.InitTokenMarket(REXE, REXEprice, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);

  REXE_init_transaction.wait();


}