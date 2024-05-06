const hre = require("hardhat");
const tokenabi = require("../scripts/token_abi.json");
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

const fs = require('fs');
const path = require('path');

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

    const EVO_LIB = await hre.ethers.deployContract("EVO_LIBRARY");

    await EVO_LIB.waitForDeployment();

    console.log("EVO Library deployed to", await EVO_LIB.getAddress());


    const Interest = await hre.ethers.getContractFactory("interestData", {
        libraries: {
            EVO_LIBRARY: await EVO_LIB.getAddress(),
        },
    });

    const Deploy_interest = await Interest.deploy(initialOwner, executor, depositvault, initialOwner, initialOwner);

    await Deploy_interest.waitForDeployment();

    console.log("Interest deployed to", await Deploy_interest.getAddress());


    const Deploy_dataHub = await hre.ethers.deployContract("DataHub", [initialOwner, executor, depositvault, oracle, await Deploy_interest.getAddress(), initialOwner]);

    await Deploy_dataHub.waitForDeployment();

    console.log("Datahub deployed to", await Deploy_dataHub.getAddress());

    const depositVault = await hre.ethers.getContractFactory("DepositVault", {
        libraries: {
            EVO_LIBRARY: await EVO_LIB.getAddress(),
        },
    });
    const Deploy_depositVault = await depositVault.deploy(initialOwner, await Deploy_dataHub.getAddress(), initialOwner, await Deploy_interest.getAddress());

    await Deploy_depositVault.waitForDeployment();

    console.log("Deposit Vault deployed to", await Deploy_depositVault.getAddress());


    const DeployOracle = await hre.ethers.deployContract("Oracle", [initialOwner,
        Deploy_dataHub.getAddress(),
        Deploy_depositVault.getAddress(),
        initialOwner])

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


    const selectedSigner = signers[1];

    const REXE = await hre.ethers.deployContract("REXE", [selectedSigner.address]);

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

    const tradeFees = [0, 0];

    const USDTprice = "1000000000000000000"
    const USDTCollValue = '1000000000000000000'
    const USDTinitialMarginFee = "5000000000000000" // 0.5% //0.05 (5*16)
    const USDTliquidationFee = "30000000000000000"//( 3**17) was 30
    const USDTinitialMarginRequirement = "200000000000000000"//( 2**18) was 200
    const USDTMaintenanceMarginRequirement = "100000000000000000" // .1 ( 10*17)
    const USDToptimalBorrowProportion = "700000000000000000"//( 7**18) was 700
    const USDTmaximumBorrowProportion = "1000000000000000000"//( 10**18) was 1000
    const USDTInterestRate = "5000000000000000"//( 5**16) was 5
    const USDT_interestRateInfo = ["5000000000000000", "150000000000000000", "1000000000000000000"] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000



    const REXEprice = "2000000000000000000"; /// 0.5 cents  = "500000000000000000"

    const EVOXCollValue = '1000000000000000000'
    const REXEinitialMarginFee = "10000000000000000";
    const REXEliquidationFee = "100000000000000000";
    const REXEinitialMarginRequirement = "500000000000000000"
    const REXEMaintenanceMarginRequirement = "250000000000000000"
    const REXEoptimalBorrowProportion = "700000000000000000"
    const REXEmaximumBorrowProportion = "1000000000000000000"
    const REXEInterestRate = "5000000000000000"
    const REXEinterestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]


    const DataHub = new hre.ethers.Contract(await Deploy_dataHub.getAddress(), DataHubAbi.abi, signers[0]);

    const deposit_vault = new hre.ethers.Contract(await Deploy_depositVault.getAddress(), depositABI.abi, signers[0])

    const Oracle = new hre.ethers.Contract(await DeployOracle.getAddress(), OracleABI.abi, signers[0]);

    const Utils = new hre.ethers.Contract(await Deploy_Utilities.getAddress(), utilABI.abi, signers[0]);

    const SETUP = await Utils.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress(), await DeployOracle.getAddress(), await Deploy_interest.getAddress(), await Deploy_Liquidator.getAddress(), await Deploy_Exchange.getAddress());

    SETUP.wait()

    console.log("util init done")


    const CurrentExchange = new hre.ethers.Contract(await Deploy_Exchange.getAddress(), ExecutorAbi.abi, signers[0]);

    const SETUPEX = await CurrentExchange.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress(), await DeployOracle.getAddress(), await Deploy_Utilities.getAddress(), await Deploy_interest.getAddress(), await Deploy_Liquidator.getAddress());

    SETUPEX.wait()




    const setupDV = await deposit_vault.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_Exchange.getAddress(), await Deploy_interest.getAddress())

    setupDV.wait();


    const CurrentLiquidator = new hre.ethers.Contract(await Deploy_Liquidator.getAddress(), LiquidatorAbi.abi, signers[0]);

    const liqSetup = await CurrentLiquidator.alterAdminRoles(await Deploy_Exchange.getAddress());

    liqSetup.wait();





    const setup = await DataHub.alterAdminRoles(await Deploy_depositVault.getAddress(), await Deploy_Exchange.getAddress(), await DeployOracle.getAddress(), await Deploy_interest.getAddress(), await Deploy_Utilities.getAddress());

    setup.wait();

 

    const oraclesetup = await Oracle.alterAdminRoles(await Deploy_Exchange.getAddress(), await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress());

    oraclesetup.wait();



    const _Interest = new hre.ethers.Contract(await Deploy_interest.getAddress(), InterestAbi.abi, signers[0]);


    const interestSetup = await _Interest.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_Exchange.getAddress(), await Deploy_depositVault.getAddress(), await Deploy_Utilities.getAddress());


    interestSetup.wait();



    const InitRatesREXE = await _Interest.initInterest(await REXE.getAddress(), 1, REXEinterestRateInfo, REXEInterestRate)
    const InitRatesUSDT = await _Interest.initInterest(await USDT.getAddress(), 1, USDT_interestRateInfo, USDTInterestRate)

    InitRatesREXE.wait();
    InitRatesUSDT.wait();


    const USDT_init_transaction = await DataHub.InitTokenMarket(await USDT.getAddress(), USDTprice, USDTCollValue, tradeFees, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);

    const USDT_toggleTokenTransferFee = await DataHub.toggleTokenTransferFee(await USDT.getAddress(), "3000") // 0.003% ==> 3  // 3000 for 3% percentage of fees. 

    const USDT_ViewTokenTransferFees = await DataHub.ViewTokenTransferFees(await USDT.getAddress());

    // const ViewTokenTransferFees = USDT_ViewTokenTransferFees.wait();

    console.log(USDT_ViewTokenTransferFees, "tradingfeeeee ")

    USDT_init_transaction.wait();

    USDT_toggleTokenTransferFee.wait();



    const REXE_init_transaction = await DataHub.InitTokenMarket(await REXE.getAddress(), REXEprice, EVOXCollValue, tradeFees, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);

    REXE_init_transaction.wait();



    console.log("init complete")


    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////

    //DEPOSIT TOKENS

    const contractABI = tokenabi.abi; // token abi for approvals 
    // taker deposit amounts 
    const deposit_amount = "500000000000000000000"

    const TOKENCONTRACT = new hre.ethers.Contract(await USDT.getAddress(), contractABI, signers[0]);
    // Wait for approval transaction to finish
    const approvalTx = await TOKENCONTRACT.approve(await Deploy_depositVault.getAddress(), deposit_amount);
    await approvalTx.wait();  // Wait for the transaction to be mined

    const transfer = await TOKENCONTRACT.transfer(signers[1].address, "20000000000000000000000");

    await transfer.wait();

    const DVault = new hre.ethers.Contract(await Deploy_depositVault.getAddress(), depositABI.abi, signers[0]);

    await DVault.deposit_token(
        await USDT.getAddress(),
        deposit_amount
    )

    const deposit_amount_2 = "1000000000000000000000"

    const TOKENCONTRACT_2 = new hre.ethers.Contract(await REXE.getAddress(), tokenabi.abi, signers[1]);
    // Wait for approval transaction to finish
    const approvalTx_2 = await TOKENCONTRACT_2.approve(await Deploy_depositVault.getAddress(), "5000000000000000000000");
    await approvalTx_2.wait();  // Wait for the transaction to be mined


    const DVM = new hre.ethers.Contract(await Deploy_depositVault.getAddress(), depositABI.abi, signers[1]);

    await DVM.deposit_token(
        await REXE.getAddress(),
        deposit_amount_2
    )

    const deposit_amount_3 = "1000000000000000000000"
    const TOKENCONTRACT_3 = new hre.ethers.Contract(await USDT.getAddress(), tokenabi.abi, signers[1]);

    const approvalTx_3 = await TOKENCONTRACT_3.approve(await Deploy_depositVault.getAddress(), deposit_amount_2);

    await approvalTx_3.wait();  // Wait for the transaction to be mined

    await DVM.deposit_token(
        await USDT.getAddress(),
        deposit_amount_3)
    console.log("deposits complete")
    ///////////////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////////////

    console.log("deposit successful moving to withdraw")

    await DVM.withdraw_token(await USDT.getAddress(),
    deposit_amount_2);

    console.log("withdraw success")


}
//npx hardhat run scripts/deploy.js 
main().then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });



