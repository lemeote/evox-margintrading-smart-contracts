const hre = require("hardhat");
const { expect } = require("chai");
const {
    loadFixture,
  } = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const tokenabi = require("../scripts/token_abi.json");
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")
const OracleABI = require("../artifacts/contracts/mock/MockOracle.sol/MockOracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/mock/MockDatahub.sol/MockDatahub.json");
const InterestAbi = require("../artifacts/contracts/mock/MockInterestData.sol/MockInterestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")
const increaseTime =  require("./utils.js");


const fs = require('fs');

async function getTimeStamp(provider) {
    const block = await provider.getBlock('latest');
    return block.timestamp;
}

async function setTimeStamp(provider, network, scaledTimestamp) {
    await provider.send("evm_setNextBlockTimestamp", [scaledTimestamp]);
    await network.provider.send("evm_mine");
}

describe("Margin Trading Test", function () {
  async function deployandInitContracts() {
      const signers = await hre.ethers.getSigners();
      // console.log("Deploying contracts with the account:", signers[0].address);

      const initialOwner = signers[0].address // insert wallet address 
      // insert airnode address , address _executor, address _deposit_vault
      const executor = initialOwner;
      const depositvault = initialOwner;
      const oracle = initialOwner;

      // console.log("==========================Deploy contracts===========================");
      /////////////////////////////////Deploy EVO_LIB//////////////////////////////////////
      const EVO_LIB = await hre.ethers.deployContract("EVO_LIBRARY");

      await EVO_LIB.waitForDeployment();

      // console.log("EVO Library deployed to", await EVO_LIB.getAddress());


      /////////////////////////////////Deploy Interest//////////////////////////////////////
      const Interest = await hre.ethers.getContractFactory("MockInterestData", {
          libraries: {
              EVO_LIBRARY: await EVO_LIB.getAddress(),
          },
      });

      const Deploy_interest = await Interest.deploy(initialOwner, executor, depositvault, initialOwner, initialOwner);

      await Deploy_interest.waitForDeployment();

      // console.log("Interest deployed to", await Deploy_interest.getAddress());


      /////////////////////////////////Deploy dataHub////////////////////////////////////////
      const Deploy_dataHub = await hre.ethers.deployContract("MockDatahub", [initialOwner, executor, depositvault, oracle, await Deploy_interest.getAddress(), initialOwner]);

      await Deploy_dataHub.waitForDeployment();

      // console.log("Datahub deployed to", await Deploy_dataHub.getAddress());

      /////////////////////////////////Deploy depositVault////////////////////////////////////
      const depositVault = await hre.ethers.getContractFactory("DepositVault", {
          libraries: {
              EVO_LIBRARY: await EVO_LIB.getAddress(),
          },
      });
      const Deploy_depositVault = await depositVault.deploy(initialOwner, await Deploy_dataHub.getAddress(), initialOwner, await Deploy_interest.getAddress());

      await Deploy_depositVault.waitForDeployment();

      // console.log("Deposit Vault deployed to", await Deploy_depositVault.getAddress());

      /////////////////////////////////Deploy Oracle///////////////////////////////////////////
      const DeployOracle = await hre.ethers.deployContract("MockOracle", [initialOwner,
          initialOwner,
          initialOwner,
          initialOwner])

      // console.log("Oracle deployed to", await DeployOracle.getAddress());
      
      /////////////////////////////////Deploy Utility///////////////////////////////////////////
      const Utility = await hre.ethers.getContractFactory("Utility", {
          libraries: {
              EVO_LIBRARY: await EVO_LIB.getAddress(),
          },
      });
      const Deploy_Utilities = await Utility.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), initialOwner, await Deploy_interest.getAddress());

      // console.log("Utils deployed to", await Deploy_Utilities.getAddress());

      /////////////////////////////////Deploy liquidator/////////////////////////////////////////
      const Liquidator = await hre.ethers.getContractFactory("Liquidator", {
          libraries: {
              EVO_LIBRARY: await EVO_LIB.getAddress(),
          },
      });
      const Deploy_Liquidator = await Liquidator.deploy(initialOwner, Deploy_dataHub.getAddress(), initialOwner); // need to alter the ex after 

      // console.log("Liquidator deployed to", await Deploy_Liquidator.getAddress());

      Deploy_Utilities
      const Exchange = await hre.ethers.getContractFactory("EVO_EXCHANGE", {
          libraries: {
              EVO_LIBRARY: await EVO_LIB.getAddress(),
          },
      });

      const Deploy_Exchange = await Exchange.deploy(initialOwner, Deploy_dataHub.getAddress(), Deploy_depositVault.getAddress(), DeployOracle.getAddress(), Deploy_Utilities.getAddress(), await Deploy_interest.getAddress(), Deploy_Liquidator.getAddress());

      // console.log("Deploy_Utilities deployed to", await Deploy_Utilities.getAddress());

      /////////////////////////////////Deploy REXE with singer[1]/////////////////////////////////////////
      const selectedSigner = signers[1];
      const REXE = await hre.ethers.deployContract("REXE", [selectedSigner.address]);
      const connectedREXE = REXE.connect(selectedSigner);
      await REXE.waitForDeployment();

      // console.log("REXE deployed to", await connectedREXE.getAddress());
      // console.log("REXE Balance = ", await REXE.balanceOf(signers[1].address))

      /////////////////////////////////Deploy USDT with singer[1]/////////////////////////////////////////
      const USDT = await hre.ethers.deployContract("USDT", [signers[0].address]);
      await USDT.waitForDeployment();
      // console.log("USDT deployed to", await USDT.getAddress());
      // console.log("USDB balance = ", await USDT.balanceOf(signers[0].address))

      // console.log("==========================Deploy Contracts Finished===========================");
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      
      ///////////////////////////////////////////////////////////////////////////////////////////////////////
      // INIT CONTRACTS
      // console.log("==========================Init contracts===========================");

      const tradeFees = [0, 0];
      /////////////////////// USDT /////////////////////////
      const USDTprice = 1_000000000000000000n
      const USDTCollValue = 1_000000000000000000n
      const USDTinitialMarginFee = 5000000000000000n // 0.5% //0.05 (5*16)
      const USDTliquidationFee = 30000000000000000n //( 3**17) was 30
      const USDTinitialMarginRequirement = 200000000000000000n //( 2**18) was 200
      const USDTMaintenanceMarginRequirement = 100000000000000000n // .1 ( 10*17)
      const USDToptimalBorrowProportion = 700000000000000000n //( 7**18) was 700
      const USDTmaximumBorrowProportion = 1_000000000000000000n //( 10**18) was 1000
      const USDTInterestRate = 5000000000000000n //( 5**16) was 5
      const USDT_interestRateInfo = [5000000000000000n, 150000000000000000n, 1_000000000000000000n] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000


      /////////////////////// REX /////////////////////////
      const REXEprice = 2_000000000000000000n; /// 0.5 cents  = "500000000000000000"

      const EVOXCollValue = 1_000000000000000000n
      const REXEinitialMarginFee = 10000000000000000n;
      const REXEliquidationFee = 100000000000000000n;
      const REXEinitialMarginRequirement = 500000000000000000n
      const REXEMaintenanceMarginRequirement = 250000000000000000n
      const REXEoptimalBorrowProportion = 700000000000000000n
      const REXEmaximumBorrowProportion = 1000000000000000000n
      const REXEInterestRate = 5000000000000000n
      const REXEinterestRateInfo = [5000000000000000n, 100000000000000000n, 1000000000000000000n]

      //////////////////////////////////////// Init Contracts ///////////////////////////////////////////////

      //////////////////// Init utils //////////////////////
      const Utils = new hre.ethers.Contract(await Deploy_Utilities.getAddress(), utilABI.abi, signers[0]);
      const SETUP = await Utils.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress(), await DeployOracle.getAddress(), await Deploy_interest.getAddress(), await Deploy_Liquidator.getAddress(), await Deploy_Exchange.getAddress());
      SETUP.wait()
      // console.log("util init done")

      //////////////////// Init Exchange //////////////////////
      const CurrentExchange = new hre.ethers.Contract(await Deploy_Exchange.getAddress(), ExecutorAbi.abi, signers[0]);
      const SETUPEX = await CurrentExchange.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress(), await DeployOracle.getAddress(), await Deploy_Utilities.getAddress(), await Deploy_interest.getAddress(), await Deploy_Liquidator.getAddress());
      SETUPEX.wait()
      // console.log("exchange init done")


      //////////////////// Init deposit vault //////////////////////
      const deposit_vault = new hre.ethers.Contract(await Deploy_depositVault.getAddress(), depositABI.abi, signers[0])
      const setupDV = await deposit_vault.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_Exchange.getAddress(), await Deploy_interest.getAddress())
      setupDV.wait();
      // console.log("deposit vault init done")

      //////////////////// Init liquidator //////////////////////
      const CurrentLiquidator = new hre.ethers.Contract(await Deploy_Liquidator.getAddress(), LiquidatorAbi.abi, signers[0]);
      const liqSetup = await CurrentLiquidator.alterAdminRoles(await Deploy_Exchange.getAddress());
      liqSetup.wait();
      // console.log("liquidator init done")

      //////////////////// Init Datahub //////////////////////
      const DataHub = new hre.ethers.Contract(await Deploy_dataHub.getAddress(), DataHubAbi.abi, signers[0]);
      const setup = await DataHub.alterAdminRoles(await Deploy_depositVault.getAddress(), await Deploy_Exchange.getAddress(), await DeployOracle.getAddress(), await Deploy_interest.getAddress(), await Deploy_Utilities.getAddress());
      setup.wait();
      // console.log("datahub init done")

      //////////////////// Init Oracle //////////////////////
      const Oracle = new hre.ethers.Contract(await DeployOracle.getAddress(), OracleABI.abi, signers[0]);
      const oraclesetup = await Oracle.alterAdminRoles(await Deploy_Exchange.getAddress(), await Deploy_dataHub.getAddress(), await Deploy_depositVault.getAddress());
      oraclesetup.wait();
      // console.log("oracle init done")
      
      //////////////////// Init interest //////////////////////
      const _Interest = new hre.ethers.Contract(await Deploy_interest.getAddress(), InterestAbi.abi, signers[0]);
      const interestSetup = await _Interest.alterAdminRoles(await Deploy_dataHub.getAddress(), await Deploy_Exchange.getAddress(), await Deploy_depositVault.getAddress(), await Deploy_Utilities.getAddress());
      interestSetup.wait();
      // console.log("interest init done")

      //////////////////// Set USDT and REXE in interestData //////////////////////
      const InitRatesREXE = await _Interest.initInterest(await REXE.getAddress(), 1, REXEinterestRateInfo, REXEInterestRate)
      const InitRatesUSDT = await _Interest.initInterest(await USDT.getAddress(), 1, USDT_interestRateInfo, USDTInterestRate)
      InitRatesREXE.wait();
      InitRatesUSDT.wait();
      // console.log("Set USDT and REXE in interestData done")

      //////////////////// InitTokenMarket USDT in DataHub //////////////////////
      const USDT_init_transaction = await DataHub.InitTokenMarket(await USDT.getAddress(), USDTprice, USDTCollValue, tradeFees, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);
      USDT_init_transaction.wait();
      // console.log("InitTokenMarket USDT in DataHub done")

      //////////////////// InitTokenMarket REXE in DataHub //////////////////////
      const REXE_init_transaction = await DataHub.InitTokenMarket(await REXE.getAddress(), REXEprice, EVOXCollValue, tradeFees, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);
      REXE_init_transaction.wait();
      // console.log("InitTokenMarket REXE in DataHub done")

      ///////////////////////////////// Getting Token Contracts //////////////////////////////////////
      const contractABI = tokenabi.abi; // token abi for approvals 

      // Get USDT Contract
      const USDT_TOKEN = new hre.ethers.Contract(await USDT.getAddress(), contractABI, signers[0]);

      // Get Rexe Contract
      const REXE_TOKEN = new hre.ethers.Contract(await REXE.getAddress(), contractABI, signers[0]);

      // const USDT_setTokenTransferFee = await DataHub.setTokenTransferFee(await USDT_TOKEN.getAddress(), 0) // 0.003% ==> 3  // 3000 for 3% percentage of fees. 
      // USDT_setTokenTransferFee.wait();
      // expect(await DataHub.tokenTransferFees(await USDT_TOKEN.getAddress())).to.equal(0);

      // const REXE_setTokenTransferFee = await DataHub.setTokenTransferFee(await REXE_TOKEN.getAddress(), 0) // 0.003% ==> 3  // 3000 for 3% percentage of fees. 
      // REXE_setTokenTransferFee.wait();
      // expect(await DataHub.tokenTransferFees(await REXE_TOKEN.getAddress())).to.equal(0);

      await Oracle.setUSDT(await USDT_TOKEN.getAddress());


      // console.log("================================Init Contracts Finished=============================")

      return {signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN};
  }

  describe("Deployment", function () {
      it("Deploy and Init All contracts ", async function () {
          const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);
          // Add All expect causes
          // DataHub.returnAssetLogs(USDT_TOKEN.getAddress().initialized).to.equal(true);
          expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).initialized).to.equal(true);
          // DataHub.returnAssetLogs(REXE_TOKEN.getAddress().initialized).to.equal(true);
          expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).initialized).to.equal(true);
      })
  })

  describe("Margin Trading Underflow Test", function () {
    it("Test margin trade that makes the users have assets with a greater value than the liabilities", async function () {
      const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);

      const deposit_amount = 500_000000000000000000n;

      const approvalTx = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount);
      await approvalTx.wait();  // Wait for the transaction to be mined

      const transfer = await USDT_TOKEN.transfer(signers[1].address, 20_000_000000000000000000n);
      await transfer.wait();

      expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);
      expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).totalAssetSupply).to.equal(0);
      
      await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount)
      // totalAssetSupply of USDT should be same as deposit_amount after deposit
      expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).totalAssetSupply).to.equal(deposit_amount);
      expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount);
      expect((await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount); // compare assets in datahub

      expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);


      // REXE Deposit
      const deposit_amount_2 = 5_000_000000000000000000n

      const approvalTx1 = await REXE_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount);
      await approvalTx1.wait();  // Wait for the transaction to be mined

      // const transfer1 = await REXE_TOKEN.connect(signers[1]).transfer(signers[0].address, deposit_amount_2);
      // await transfer1.wait();

      // expect(await REXE_TOKEN.balanceOf(signers[0].address)).to.equal(deposit_amount_2);
      expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).totalAssetSupply).to.equal(0);

      const approvalTx_2 = await REXE_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount_2);
      await approvalTx_2.wait();  // Wait for the transaction to be mined
      await deposit_vault.connect(signers[1]).deposit_token(await REXE_TOKEN.getAddress(), (deposit_amount_2));

      expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).totalAssetSupply).to.equal(deposit_amount_2);
      expect(await REXE_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount_2);
      expect((await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress()))[0]).to.equal(deposit_amount_2); // compare assets in datahub

      // expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);

      // USDT Deposit
      const deposit_amount_3 = 1_000_000000000000000000n

      const approvalTx_3 = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount_3);
      await approvalTx_3.wait();  // Wait for the transaction to be mined
      await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount_3)

      expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).totalAssetSupply).to.equal(deposit_amount + deposit_amount_3);
      expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount + deposit_amount_3);
      expect((await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount + deposit_amount_3); // compare assets in datahub
      console.log("data hub address", await DataHub.getAddress());
      // const test_supply_amount = 1500_000000000000000000n;
      // await DataHub.settotalAssetSupplyTest(await USDT_TOKEN.getAddress(), test_supply_amount, true);

      const Data = {
          "taker_out_token": await USDT_TOKEN.getAddress(),  //0x0165878A594ca255338adfa4d48449f69242Eb8F 
          "maker_out_token": await REXE_TOKEN.getAddress(), //0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
          "takers": signers[0].address, //0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
          "makers": signers[1].address, //0x70997970c51812dc3a010c7d01b50e0d17dc79c8
          "taker_out_token_amount": 1_250_000000000000000000n, // 12000000000000000000 // 1250
          "maker_out_token_amount": 2_500_000000000000000000n, // 12000000000000000000  // 2500
      }
      /// 
      const trade_sides = [[true], [false]];
      const pair = [Data.taker_out_token, Data.maker_out_token];
      const participants = [[Data.takers], [Data.makers]];
      const trade_amounts = [[Data.taker_out_token_amount], [Data.maker_out_token_amount]];

      // const EX = new hre.ethers.Contract(await Deploy_Exchange.getAddress(), ExecutorAbi.abi, signers[0]);

      const originTimestamp = await getTimeStamp(hre.ethers.provider);
      console.log('Origin timestamp:', originTimestamp);

      let test = await _Interest.fetchCurrentRateIndex(await USDT_TOKEN.getAddress());
      console.log("USDT rate", test);

      const scaledTimestamp = originTimestamp + 3600;

      setTimeStamp(hre.ethers.provider, network, scaledTimestamp);
      // await increaseTime()
      console.log(`Set timestamp to ${scaledTimestamp}`);

      const masscharges_usdt = await _Interest.chargeMassinterest(await USDT_TOKEN.getAddress()); // increase borrow amount
      await masscharges_usdt.wait(); // Wait for the transaction to be mined

      // const masscharges_rexe = await _Interest.chargeMassinterest(await REXE_TOKEN.getAddress()); // increase borrow amount
      // await masscharges_rexe.wait(); // Wait for the transaction to be mined
      await CurrentExchange.SubmitOrder(pair, participants, trade_amounts, trade_sides)
    })
  })
})
