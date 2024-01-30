const hre = require("hardhat");
const tokenabi = require("../scripts/token_abi.json");
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/REX_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");

async function main() {
  /// const [deployer] = await hre.ethers.getSigners(0);
  //console.log(signers[0].address)
  //console.log(signers[1].address)

  const signers = await hre.ethers.getSigners();
  console.log("Deploying contracts with the account:", signers[0].address);



  const initialOwner = signers[0].address // insert wallet address 
  // insert airnode address , address _executor, address _deposit_vault
  const executor = initialOwner;
  const depositvault = initialOwner;
  const oracle = initialOwner;
  // Deploy REXE library

  const REX_LIB = await hre.ethers.deployContract("REX_LIBRARY");

  await REX_LIB.waitForDeployment();

  console.log("REX Library deployed to", await REX_LIB.getAddress());

  const DATAHUB = await hre.ethers.getContractFactory("DataHub", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });
  const Deploy_dataHub = await DATAHUB.deploy(initialOwner, executor, depositvault, oracle);

  await Deploy_dataHub.waitForDeployment();

  console.log("Datahub deployed to", await Deploy_dataHub.getAddress());

  const depositVault = await hre.ethers.getContractFactory("DepositVault", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });
  const Deploy_depositVault = await depositVault.deploy(initialOwner, Deploy_dataHub.getAddress());

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
  const Deploy_Utilities = await Utility.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), initialOwner);

  console.log("Utils deployed to", await Deploy_Utilities.getAddress());

  const Exchange = await hre.ethers.getContractFactory("REX_EXCHANGE", {
    libraries: {
      REX_LIBRARY: await REX_LIB.getAddress(),
    },
  });


  const Deploy_Exchange = await Exchange.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), Deploy_Utilities.getAddress());

  console.log("Exchange deployed to", await Deploy_Exchange.getAddress());



  const selectedSigner = signers[1];

  // Deploy the contract without specifying the `from` field
  const REXE = await hre.ethers.deployContract("REXE", [selectedSigner.address]);

  // Connect the contract instance to the selected signer
  const connectedREXE = REXE.connect(selectedSigner);

  await REXE.waitForDeployment();

  console.log("REXE deployed to", await connectedREXE.getAddress());

  console.log(await REXE.balanceOf(signers[1].address))


  const USDT = await hre.ethers.deployContract("USDT", [signers[0].address]);


  await USDT.waitForDeployment();


  console.log("USDT deployed to", await USDT.getAddress());

  console.log(await USDT.balanceOf(signers[0].address))


  ///////////////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////////////
  // INIT CONTRACTS

  const USDTprice = "1000000000000000000"

  const USDTinitialMarginFee = "5000000000000000" // 0.5% //0.05 (5*16)
  const USDTliquidationFee = "30000000000000000"//( 3**17) was 30
  const USDTinitialMarginRequirement = "200000000000000000"//( 2**18) was 200
  const USDTMaintenanceMarginRequirement = "100000000000000000" // .1 ( 10*17)
  const USDToptimalBorrowProportion = "700000000000000000"//( 7**18) was 700
  const USDTmaximumBorrowProportion = "1000000000000000000"//( 10**18) was 1000
  const USDTInterestRate = "5000000000000000"//( 5**16) was 5
  const USDT_interestRateInfo = ["5000000000000000", "150000000000000000", "1000000000000000000"] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000



  const REXEprice = "2000000000000000000"; /// 0.5 cents  = "500000000000000000"

  const REXEinitialMarginFee = "10000000000000000";
  const REXEliquidationFee = "10000000000000000";
  const REXEinitialMarginRequirement = "500000000000000000"
  const REXEMaintenanceMarginRequirement = "250000000000000000"
  const REXEoptimalBorrowProportion = "700000000000000000"
  const REXEmaximumBorrowProportion = "1000000000000000000"
  const REXEInterestRate = "5000000000000000"
  const REXEinterestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]


  const DataHub = new hre.ethers.Contract(await Deploy_dataHub.getAddress(), DataHubAbi.abi, signers[0]);

  const Oracle = new hre.ethers.Contract(await DeployOracle.getAddress(), OracleABI.abi, signers[0]);

  const Utils = new hre.ethers.Contract(await Deploy_Utilities.getAddress(), utilABI.abi, signers[0]);

  const SETUP = await Utils.AlterExchange(await Deploy_Exchange.getAddress());

  SETUP.wait()

  const CurrentExchange = new hre.ethers.Contract(await Deploy_Exchange.getAddress(), ExecutorAbi.abi, signers[0]);

  const SETUPEX = await CurrentExchange.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress(), await DeployOracle.getAddress(), await Deploy_Utilities.getAddress());

  SETUPEX.wait()


  const setup = await DataHub.AlterAdminRoles(await Deploy_depositVault.getAddress(), await Deploy_Exchange.getAddress(), await DeployOracle.getAddress());

  setup.wait();

  const oraclesetup = await Oracle.AlterExecutor(await Deploy_Exchange.getAddress());

  oraclesetup.wait();

  const USDT_init_transaction = await DataHub.InitTokenMarket(await USDT.getAddress(), USDTprice, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion, USDTInterestRate, USDT_interestRateInfo);


  USDT_init_transaction.wait();


  const REXE_init_transaction = await DataHub.InitTokenMarket(await REXE.getAddress(), REXEprice, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion, REXEInterestRate, REXEinterestRateInfo);

  REXE_init_transaction.wait();

  console.log("init complete")


  ///////////////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////////////

  //DEPOSIT TOKENS

  const contractABI = tokenabi.abi; // token abi for approvals 
  // taker deposit amounts 
  const deposit_amount = "20000000000000000000"

  const TOKENCONTRACT = new hre.ethers.Contract(await USDT.getAddress(), contractABI, signers[0]);
  // Wait for approval transaction to finish
  const approvalTx = await TOKENCONTRACT.approve(await Deploy_depositVault.getAddress(), deposit_amount);
  await approvalTx.wait();  // Wait for the transaction to be mined

  const transfer = await TOKENCONTRACT.transfer(signers[1].address, "200000000000000000000" );

  transfer.wait();


  console.log("Deposit with account:", signers[0].address);

  const DVault = new hre.ethers.Contract(await Deploy_depositVault.getAddress(), depositABI.abi, signers[0]);

  DVault.deposit_token(
    await USDT.getAddress(),
    deposit_amount
  )


  const deposit_amount_2 = "200000000000000000000"

  const TOKENCONTRACT_2 = new hre.ethers.Contract(await REXE.getAddress(), tokenabi.abi, signers[1]);
  // Wait for approval transaction to finish
  const approvalTx_2 = await TOKENCONTRACT_2.approve(await Deploy_depositVault.getAddress(), deposit_amount_2);
  await approvalTx_2.wait();  // Wait for the transaction to be mined

  console.log("Deposit with account:", signers[1].address);

  const DVM = new hre.ethers.Contract(await Deploy_depositVault.getAddress(), depositABI.abi, signers[1]);

  await DVM.deposit_token(
    await REXE.getAddress(),
    deposit_amount_2
  )
  const TOKENCONTRACT_3 = new hre.ethers.Contract(await USDT.getAddress(), tokenabi.abi, signers[1]);

  const approvalTx_3 = await TOKENCONTRACT_3.approve(await Deploy_depositVault.getAddress(), deposit_amount_2);

  await approvalTx_3.wait();  // Wait for the transaction to be mined

  await DVM.deposit_token(
    await USDT.getAddress(),
    deposit_amount_2)

  ///////////////////////////////////////////////////////////////////////////////////////////////////////
  ///////////////////////////////////////////////////////////////////////////////////////////////////////

  //TRADE

  //console.log("Submitting orders with the account:", signers[0].address);

 // console.log(await DataHub.ReadUserData(signers[1].address, await REXE.getAddress()), "user data");

  const Data = {
    "taker_out_token": await USDT.getAddress() ,  //0x0165878A594ca255338adfa4d48449f69242Eb8F 
    "maker_out_token": await REXE.getAddress(), //0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
    "takers": signers[0].address, //0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
    "makers": signers[1].address, //0x70997970c51812dc3a010c7d01b50e0d17dc79c8
    "taker_out_token_amount": "24000000000000000000", // 12000000000000000000
    "maker_out_token_amount": "12000000000000000000", // 12000000000000000000    (12 tokens leaving takers wallet)
  }
/// 
  const pair = [Data.taker_out_token, Data.maker_out_token];
  const participants = [[Data.takers], [Data.makers]];
  const trade_amounts = [[Data.taker_out_token_amount], [Data.maker_out_token_amount]];

 // console.log(pair, participants, trade_amounts)

  const EX = new hre.ethers.Contract(await Deploy_Exchange.getAddress(), ExecutorAbi.abi, signers[0]);
  // Perform testing actions

  const utils = new hre.ethers.Contract(await Deploy_Utilities.getAddress(), utilABI.abi, signers[0]);

  const assetsbulk = await utils.returnBulkAssets(
    [signers[0].address],
    await USDT.getAddress()
  )
  console.log(assetsbulk, "userassets")

  const logs = await DataHub.returnAssetLogs(await REXE.getAddress()) // rexe


  console.log(await DataHub.ReadUserData(signers[0].address, USDT), "signer0, usdt") // taker has 10 usdt 
  console.log(await DataHub.ReadUserData(signers[0].address, REXE), "signer0 REXE") // taker has 0 rexe 
  console.log(await DataHub.ReadUserData(signers[1].address, USDT), "signer1, usdt") // maker has 20 usdt 
  console.log(await DataHub.ReadUserData(signers[1].address, REXE), "signer1 REXE") // maker has 20 rexe 


  await EX.SubmitOrder(pair, participants, trade_amounts)

  console.log(await DataHub.ReadUserData(signers[0].address, USDT), "signer0, usdt") // taker has 10 usdt 
  console.log(await DataHub.ReadUserData(signers[0].address, REXE), "signer0 REXE") // taker has 0 rexe 
  console.log(await DataHub.ReadUserData(signers[1].address, USDT), "signer1, usdt") // maker has 20 usdt 
  console.log(await DataHub.ReadUserData(signers[1].address, REXE), "signer1 REXE") // maker has 20 rexe 


  const NEWData = {
    "taker_out_token": await REXE.getAddress() ,  //0x0165878A594ca255338adfa4d48449f69242Eb8F 
    "maker_out_token": await USDT.getAddress(), //0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
    "takers": signers[0].address, //0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
    "makers": signers[1].address, //0x70997970c51812dc3a010c7d01b50e0d17dc79c8
    "taker_out_token_amount": "6000000000000000000", // 12000000000000000000
    "maker_out_token_amount": "15000000000000000000", // 12000000000000000000    (12 tokens leaving takers wallet)
  }
/// 
  const NEWpair = [NEWData.taker_out_token, NEWData.maker_out_token];
  const NEWparticipants = [[NEWData.takers], [NEWData.makers]];
  const NEWtrade_amounts = [[NEWData.taker_out_token_amount], [NEWData.maker_out_token_amount]];

 // console.log(pair, participants, trade_amounts)
 await EX.SubmitOrder(NEWpair, NEWparticipants, NEWtrade_amounts)

 console.log(await DataHub.ReadUserData(signers[0].address, USDT), "signer0, usdt") // taker has 10 usdt 
 console.log(await DataHub.ReadUserData(signers[0].address, REXE), "signer0 REXE") // taker has 0 rexe 
 console.log(await DataHub.ReadUserData(signers[1].address, USDT), "signer1, usdt") // maker has 20 usdt 
 console.log(await DataHub.ReadUserData(signers[1].address, REXE), "signer1 REXE") // maker has 20 rexe 

}
//npx hardhat run scripts/deploy.js 
main().then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });





// node testOrders.js


//MakeOrders("0x71A4A13Fa1703aDD4c6830dCd3c298f333addcbe", signers[1]_wallet, "LIMIT");
//FufillOrder("0x71A4A13Fa1703aDD4c6830dCd3c298f333addcbe", taker_wallet);
