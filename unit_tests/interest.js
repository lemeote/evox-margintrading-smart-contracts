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
// const MathAbi = require("../artifacts/contracts/Math.sol/Math.json")
const increaseTime =  require("./utils.js");


const fs = require('fs');
const exp = require("constants");

async function getTimeStamp(provider) {
    const block = await provider.getBlock('latest');
    return block.timestamp;
}

async function setTimeStamp(provider, network, scaledTimestamp) {
    await provider.send("evm_setNextBlockTimestamp", [scaledTimestamp]);
    await network.provider.send("evm_mine");
}

describe("Interest Test", function () {
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
        const USDTFeeInfo = [
            5000000000000000n, // USDTinitialMarginRequirement
            30000000000000000n, // USDTliquidationFee
            0 // tokenTransferFee
        ];
        const USDTMarginRequirement = [
            200000000000000000n, // initialMarginRequirement
            100000000000000000n // MaintenanceMarginRequirement
        ];
        const USDTBorrowPosition = [
            700000000000000000n, // optimalBorrowProportion
            1_000000000000000000n // maximumBorrowProportion
        ];
        const USDTInterestRate = 5000000000000000n //( 5**16) was 5
        const USDT_interestRateInfo = [5000000000000000n, 150000000000000000n, 1_000000000000000000n] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000

        /////////////////////// REX /////////////////////////
        const REXEprice = 2_000000000000000000n
        const EVOXCollValue = 1_000000000000000000n
        const REXEFeeInfo = [
            10000000000000000n, // USDTinitialMarginRequirement
            100000000000000000n, // USDTliquidationFee
            0 // tokenTransferFee
        ];
        const REXEMarginRequirement = [
            500000000000000000n, // initialMarginRequirement
            250000000000000000n // MaintenanceMarginRequirement
        ];
        const REXEBorrowPosition = [
            700000000000000000n, // optimalBorrowProportion
            1000000000000000000n // maximumBorrowProportion
        ];
        const REXEInterestRate = 5000000000000000n //( 5**16) was 5
        const REXE_interestRateInfo = [5000000000000000n, 150000000000000000n, 1_000000000000000000n] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000

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
        const InitRatesREXE = await _Interest.initInterest(await REXE.getAddress(), 1, REXE_interestRateInfo, REXEInterestRate)
        const InitRatesUSDT = await _Interest.initInterest(await USDT.getAddress(), 1, USDT_interestRateInfo, USDTInterestRate)
        InitRatesREXE.wait();
        InitRatesUSDT.wait();
        // console.log("Set USDT and REXE in interestData done")

        //////////////////// InitTokenMarket USDT in DataHub //////////////////////
        const USDT_init_transaction = await DataHub.InitTokenMarket(await USDT.getAddress(), USDTprice, USDTCollValue, tradeFees, USDTMarginRequirement, USDTBorrowPosition, USDTFeeInfo);
        USDT_init_transaction.wait();
        // console.log("InitTokenMarket USDT in DataHub done")

        //////////////////// InitTokenMarket REXE in DataHub //////////////////////
        const REXE_init_transaction = await DataHub.InitTokenMarket(await REXE.getAddress(), REXEprice, EVOXCollValue, tradeFees, REXEMarginRequirement, REXEBorrowPosition, REXEFeeInfo);
        REXE_init_transaction.wait();
        // console.log("InitTokenMarket REXE in DataHub done")

        ///////////////////////////////// Getting Token Contracts //////////////////////////////////////
        const contractABI = tokenabi.abi; // token abi for approvals 

        // Get USDT Contract
        const USDT_TOKEN = new hre.ethers.Contract(await USDT.getAddress(), contractABI, signers[0]);

        // Get Rexe Contract
        const REXE_TOKEN = new hre.ethers.Contract(await REXE.getAddress(), contractABI, signers[0]);

        const USDT_setTokenTransferFee = await DataHub.setTokenTransferFee(await USDT_TOKEN.getAddress(), 0) // 0.003% ==> 3  // 3000 for 3% percentage of fees. 
        USDT_setTokenTransferFee.wait();
        expect(await DataHub.tokenTransferFees(await USDT_TOKEN.getAddress())).to.equal(0);

        const REXE_setTokenTransferFee = await DataHub.setTokenTransferFee(await REXE_TOKEN.getAddress(), 0) // 0.003% ==> 3  // 3000 for 3% percentage of fees. 
        REXE_setTokenTransferFee.wait();
        expect(await DataHub.tokenTransferFees(await REXE_TOKEN.getAddress())).to.equal(0);

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

    describe("Trading Test", function () {
        it("Submit Order Function Test", async function () {
            return;
            const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);
            // console.log(signers);
            ///////////////////////////////////////////////////////////////////////////////////////////////////////

            // Set USDT Address in Oracle
            await Oracle.setUSDT(await USDT_TOKEN.getAddress());

            /////////////////////////////// DEPOSIT TOKENS //////////////////////////////////
            // console.log("==================== deposit tokens======================");
            // taker deposit amounts 
            // USDT Deposit
            const deposit_amount = 500_000000000000000000n

            const approvalTx = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount);
            await approvalTx.wait();  // Wait for the transaction to be mined

            const transfer = await USDT_TOKEN.transfer(signers[1].address, 20_000_000000000000000000n);
            await transfer.wait();

            expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(0);
           
            await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount)
            // assetInfo[0] of USDT should be same as deposit_amount after deposit
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount);
            expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount);
            expect((await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount); // compare assets in datahub

            expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);


            // REXE Deposit
            const deposit_amount_2 = 1_000_000000000000000000n;

            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(0);

            const approvalTx_2 = await REXE_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), 5_000_000000000000000000n);
            await approvalTx_2.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[1]).deposit_token(await REXE_TOKEN.getAddress(), (5_000_000000000000000000n));

            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(5_000_000000000000000000n);
            expect(await REXE_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(5_000_000000000000000000n);
            expect((await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress()))[0]).to.equal(5_000_000000000000000000n); // compare assets in datahub

            // expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);

            // USDT Deposit
            const deposit_amount_3 = 1_000_000000000000000000n

            const approvalTx_3 = await USDT_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount_3);
            await approvalTx_3.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[1]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount_3)

            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount + deposit_amount_3);
            expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount + deposit_amount_3);
            expect((await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount); // compare assets in datahub
            expect((await DataHub.ReadUserData(signers[1].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount_3); // compare assets in datahub
            

            ///////////////////////////////////////////////////////////////////////////////////////////////////////
            ///////////////////////////////////////////////////////////////////////////////////////////////////////

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

            ///////////////////////////////////////////////////// SUBMIT ORDER ////////////////////////////////////////////////////

            let allData = [];
            // for (let i = 0; i <= 174; i++) {
            for (let i = 0; i < 2; i++) {

                console.log("////////////////////////////////////////////////////////// LOOP " + i + " /////////////////////////////////////////////////////////////");
                const scaledTimestamp = originTimestamp + i * 3600;

                // await hre.ethers.provider.send("evm_setNextBlockTimestamp", [scaledTimestamp]);
                // await network.provider.send("evm_mine");
                setTimeStamp(hre.ethers.provider, network, scaledTimestamp);
                // await increaseTime()
                console.log(`Loop ${i}: Set timestamp to ${scaledTimestamp}`);

                const masscharges_usdt = await _Interest.chargeMassinterest(await USDT_TOKEN.getAddress()); // increase borrow amount
                await masscharges_usdt.wait(); // Wait for the transaction to be mined

                // const masscharges_rexe = await _Interest.chargeMassinterest(await REXE_TOKEN.getAddress()); // increase borrow amount
                // await masscharges_rexe.wait(); // Wait for the transaction to be mined

                if (i == 1) {
                    await CurrentExchange.SubmitOrder(pair, participants, trade_amounts, trade_sides)

                    // console.log(await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()), "signer0, usdt") // taker has 10 usdt 
                    // console.log(await DataHub.ReadUserData(signers[0].address, await REXE_TOKEN.getAddress()), "signer0 REXE") // taker has 0 rexe 
                    // console.log(await DataHub.ReadUserData(signers[1].address, await USDT_TOKEN.getAddress()), "signer1, usdt") // maker has 20 usdt 
                    // console.log(await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress()), "signer1 REXE") // maker has 20 rexe 

                    // console.log(await DataHub.calculateAMMRForUser(signers[0].address), "ammr");
                    // console.log(await DataHub.returnPairMMROfUser(signers[0].address, await USDT_TOKEN.getAddress(), await REXE_TOKEN.getAddress()), "mmr");
                }

                // Get borrowed amount
                let borrowed_usdt = (await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[1];
                // borrowed_usdt = borrowed_usdt.totalLiabilitiesAtIndex
                // console.log("USDT borrowed", borrowed_usdt);

                // let borrowed_rexe = (await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[1];
                // borrowed_rexe = borrowed_rexe.totalLiabilitiesAtIndex
                // console.log("REXE borrowed", borrowed_rexe);
                
                // Fetch current interest RATE
                let Rate_usdt = await _Interest.fetchCurrentRate(await USDT_TOKEN.getAddress());
                // console.log("USDT rate", Rate_usdt);

                // let Rate_rexe = await _Interest.fetchCurrentRate(await REXE_TOKEN.getAddress());
                // console.log("REXE rate", Rate_rexe);

                // Get liability
                let userData_usdt = await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress());
                let liabilitiesValue_usdt = userData_usdt[1];
                // console.log("USDT liabilitiesValue", liabilitiesValue_usdt);

                // let userData_rexe = await DataHub.ReadUserData(signers[0].address, await REXE_TOKEN.getAddress());
                // let liabilitiesValue_rexe = userData_rexe[1];
                // console.log("REXE liabilitiesValue", liabilitiesValue_rexe);

                // Get interestadjustedliability
                let interestadjustedLiabilities_usdt = await _Interest.returnInterestCharge(
                    signers[0].address,
                    await USDT_TOKEN.getAddress(),
                    0
                )
                console.log("USDT interestadjustedLiabilities", interestadjustedLiabilities_usdt);

                // let interestadjustedLiabilities_rexe = await _Interest.returnInterestCharge(
                //     signers[0].address,
                //     await REXE_TOKEN.getAddress(),
                //     0
                // )
                // console.log("REXE interestadjustedLiabilities", interestadjustedLiabilities_rexe);

                let interestIndex_usdt = await _Interest.fetchCurrentRateIndex(await USDT_TOKEN.getAddress());
                // let interestIndex_rexe = await _Interest.fetchCurrentRateIndex(await REXE_TOKEN.getAddress());
                let hourly_rate_usdt = Number(Rate_usdt.toString()) / 8736;
                // let hourly_rate_rexe = Number(Rate_rexe.toString()) / 8736;
                
                let user_usdt_data = await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress());
                // let rexe_usdt_data = await DataHub.ReadUserData(signers[0].address, await REXE_TOKEN.getAddress());

                let usdt_amount = user_usdt_data[0];    
                // let rexe_amount = rexe_usdt_data[0];
                let usdt_supply = (await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0];
                // let rexe_supply = (await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0];

                //    https://docs.google.com/spreadsheets/u/5/d/1IS3WFMcbda7v_rshOefMGGS70yabp6qJ2PmDcBs8J1w/edit?usp=sharing&pli=1
                // Go above and refer to line 1-5 for the excel sheet to check numbers against what we have 

                // Create a data object for the current iteration
                const newData = {
                    "USDT" : {
                        "index": Number(interestIndex_usdt.toString()),
                        "loop #": i,
                        "usdt_amount": Number(usdt_amount.toString()) / 10 ** 18,
                        "usdt_supply" : Number(usdt_supply.toString()) / 10 ** 18,
                        "total-borrowed": Number(borrowed_usdt.toString()) / 10 ** 18,
                        "rate": Number(Rate_usdt.toString()) / 10 ** 18,
                        "hourly-rate": hourly_rate_usdt / 10 ** 18,
                        "liabilities": Number(Number(liabilitiesValue_usdt) + Number(interestadjustedLiabilities_usdt)) / 10 ** 18,
                        "timestamp": Number(scaledTimestamp.toString()),
                    },
                    // "REXE" : {
                    //     "index": Number(interestIndex_rexe.toString()),
                    //     "loop #": i,
                    //     "rexe_amount" : Number(rexe_amount.toString()) / 10 ** 18,
                    //     "rexe_supply" : Number(rexe_supply.toString()) / 10 ** 18,
                    //     "total-borrowed": Number(borrowed_rexe.toString()) / 10 ** 18,
                    //     "rate": Number(Rate_rexe.toString()) / 10 ** 18,
                    //     "hourly-rate": hourly_rate_rexe / 10 ** 18,
                    //     "liabilities": Number(Number(liabilitiesValue_rexe) + Number(interestIndex_rexe)) / 10 ** 18,
                    //     "timestamp": Number(scaledTimestamp.toString()),
                    // }
                };

                // Add the data object to the array
                allData.push(newData);
            }

            // File path for the JSON file
            const filePath = './data.json';

            // Write all collected data to the JSON file
            fs.writeFileSync(filePath, JSON.stringify(allData, null, 2));

            console.log('All data recorded successfully.');
        })

        it("Test margin trade that makes the users have assets with a greater value than the liabilities", async function () {
            // return;
            const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);

            const deposit_amount = 500_000000000000000000n;

            const approvalTx = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount);
            await approvalTx.wait();  // Wait for the transaction to be mined

            const transfer = await USDT_TOKEN.transfer(signers[1].address, 20_000_000000000000000000n);
            await transfer.wait();

            expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(0);
           
            await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount)
            // assetInfo[0] of USDT should be same as deposit_amount after deposit
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount);
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
            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(0);

            const approvalTx_2 = await REXE_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount_2);
            await approvalTx_2.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[1]).deposit_token(await REXE_TOKEN.getAddress(), (deposit_amount_2));

            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount_2);
            expect(await REXE_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount_2);
            expect((await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress()))[0]).to.equal(deposit_amount_2); // compare assets in datahub

            expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);

            // USDT Deposit
            const deposit_amount_3 = 1_000_000000000000000000n

            const approvalTx_3 = await USDT_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount_3);
            // expect(await REXE_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount_2);
            await approvalTx_3.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[1]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount_3)

            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount + deposit_amount_3);
            expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount + deposit_amount_3);
            expect((await DataHub.ReadUserData(signers[1].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount_3); // compare assets in datahub
            // console.log("data hub address", await DataHub.getAddress());
            // const test_supply_amount = 1500_000000000000000000n;
            // await DataHub.setassetInfo[0]Test(await USDT_TOKEN.getAddress(), test_supply_amount, true);

            const Data_First = {
                "taker_out_token": await USDT_TOKEN.getAddress(),  //0x0165878A594ca255338adfa4d48449f69242Eb8F 
                "maker_out_token": await REXE_TOKEN.getAddress(), //0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
                "takers": signers[0].address, //0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
                "makers": signers[1].address, //0x70997970c51812dc3a010c7d01b50e0d17dc79c8
                "taker_out_token_amount": 1_250_000000000000000000n, // 12000000000000000000 // 1250
                "maker_out_token_amount": 2_500_000000000000000000n, // 12000000000000000000  // 2500
            }
            /// 
            const trade_sides_first = [[true], [false]];
            const pair_first = [Data_First.taker_out_token, Data_First.maker_out_token];
            const participants_first = [[Data_First.takers], [Data_First.makers]];
            const trade_amounts_first = [[Data_First.taker_out_token_amount], [Data_First.maker_out_token_amount]];

            // const EX = new hre.ethers.Contract(await Deploy_Exchange.getAddress(), ExecutorAbi.abi, signers[0]);

            const originTimestamp = await getTimeStamp(hre.ethers.provider);
            console.log('Origin timestamp:', originTimestamp);

            // let test = await _Interest.fetchCurrentRateIndex(await USDT_TOKEN.getAddress());
            // console.log("USDT rate", test);

            let scaledTimestamp = originTimestamp + 3600;

            setTimeStamp(hre.ethers.provider, network, scaledTimestamp);
            // await increaseTime()
            console.log(`Set timestamp to ${scaledTimestamp}`);

            // console.log("///////////////usdt address/////////////////", await USDT_TOKEN.getAddress());

            let masscharges_usdt = await _Interest.chargeMassinterest(await USDT_TOKEN.getAddress()); // increase borrow amount
            await masscharges_usdt.wait(); // Wait for the transaction to be mined

            let masscharges_rexe = await _Interest.chargeMassinterest(await REXE_TOKEN.getAddress()); // increase borrow amount
            await masscharges_rexe.wait(); // Wait for the transaction to be mined

            await CurrentExchange.SubmitOrder(pair_first, participants_first, trade_amounts_first, trade_sides_first);

            // let test = await _Interest.fetchCurrentRateIndex(await USDT_TOKEN.getAddress());
            // console.log("USDT rate", test);

            // scaledTimestamp = originTimestamp + 3600 * 2;

            // setTimeStamp(hre.ethers.provider, network, scaledTimestamp);
            // // // await increaseTime()
            // // console.log(`Set timestamp to ${scaledTimestamp}`);

            // // console.log("///////////////usdt address/////////////////", await USDT_TOKEN.getAddress());

            // masscharges_usdt = await _Interest.chargeMassinterest(await USDT_TOKEN.getAddress()); // increase borrow amount
            // await masscharges_usdt.wait(); // Wait for the transaction to be mined

            // masscharges_rexe = await _Interest.chargeMassinterest(await REXE_TOKEN.getAddress()); // increase borrow amount
            // await masscharges_rexe.wait(); // Wait for the transaction to be mined

            ////////////////////////////////////////// Token Info /////////////////////////////////////////////////
            // Get borrowed amount
            // let usdt_borrowed_amount = (await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[1];
            // console.log("usdt_borrowed_amount", usdt_borrowed_amount);

            // let usdt_totalSupply = (await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0];
            // console.log("usdt_totalSupply", usdt_totalSupply);

            // let rexe_borrowed_amount = (await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[1];
            // console.log("rexe_borrowed_amount", rexe_borrowed_amount);

            // let rexe_totalSupply = (await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0];
            // console.log("rexe_totalSupply", rexe_totalSupply);

            ////////////////////////////////////////// User Info /////////////////////////////////////////////////
            let userData_usdt_signer0 = await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress());
            let userData_rexe_signer0 = await DataHub.ReadUserData(signers[0].address, await REXE_TOKEN.getAddress());

            // console.log("userData_usdt_signer0_amount", userData_usdt_signer0[0]);
            // console.log("userData_rexe_signer0_amount", userData_rexe_signer0[0]);

            // console.log("userData_usdt_signer0_liabilities", userData_usdt_signer0[1]);
            // console.log("userData_rexe_signer0_liabilities", userData_rexe_signer0[1]);

            let userData_usdt_signer1 = await DataHub.ReadUserData(signers[1].address, await USDT_TOKEN.getAddress());
            let userData_rexe_signer1 = await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress());

            // console.log("userData_usdt_signer1_amount", userData_usdt_signer1[0]);
            // console.log("userData_rexe_signer1_amount", userData_rexe_signer1[0]);

            // console.log("userData_usdt_signer1_liabilities", userData_usdt_signer1[1]);
            // console.log("userData_rexe_signer1_liabilities", userData_rexe_signer1[1]);

            let collateral_value_singer0 = await DataHub.calculateCollateralValue(signers[0].address);
            let collateral_value_singer1 = await DataHub.calculateCollateralValue(signers[1].address);

            // console.log("collateral_value_singer0", collateral_value_singer0);
            // console.log("collateral_value_singer1", collateral_value_singer1);
            expect(Number(collateral_value_singer0)).greaterThan(0);
            expect(Number(collateral_value_singer1)).greaterThan(0);

            // let rexe_supply = (await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0];

            const Data_Second = {
                "taker_out_token": await REXE_TOKEN.getAddress(),  //0x0165878A594ca255338adfa4d48449f69242Eb8F 
                "maker_out_token": await USDT_TOKEN.getAddress(), //0xa513E6E4b8f2a923D98304ec87F64353C4D5C853
                "takers": signers[0].address, //0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266
                "makers": signers[1].address, //0x70997970c51812dc3a010c7d01b50e0d17dc79c8
                "taker_out_token_amount": 1_250_000000000000000000n, // 12000000000000000000 // 1250
                "maker_out_token_amount": 2_500_000000000000000000n, // 12000000000000000000  // 2500
            }
            /// 
            const trade_sides_second = [[true], [false]];
            const pair_second = [Data_Second.taker_out_token, Data_Second.maker_out_token];
            const participants_second = [[Data_Second.takers], [Data_Second.makers]];
            const trade_amounts_second = [[Data_Second.taker_out_token_amount], [Data_Second.maker_out_token_amount]];
            await CurrentExchange.SubmitOrder(pair_second, participants_second, trade_amounts_second, trade_sides_second);

            ////////////////////////////////////////// User Info /////////////////////////////////////////////////
            userData_usdt_signer0 = await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress());
            userData_rexe_signer0 = await DataHub.ReadUserData(signers[0].address, await REXE_TOKEN.getAddress());

            // console.log("userData_usdt_signer0_amount", userData_usdt_signer0[0]);
            // console.log("userData_rexe_signer0_amount", userData_rexe_signer0[0]);

            // console.log("userData_usdt_signer0_liabilities", userData_usdt_signer0[1]);
            // console.log("userData_rexe_signer0_liabilities", userData_rexe_signer0[1]);

            userData_usdt_signer1 = await DataHub.ReadUserData(signers[1].address, await USDT_TOKEN.getAddress());
            userData_rexe_signer1 = await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress());

            // console.log("userData_usdt_signer1_amount", userData_usdt_signer1[0]);
            // console.log("userData_rexe_signer1_amount", userData_rexe_signer1[0]);

            // console.log("userData_usdt_signer1_liabilities", userData_usdt_signer1[1]);
            // console.log("userData_rexe_signer1_liabilities", userData_rexe_signer1[1]);

            collateral_value_singer0 = await DataHub.calculateCollateralValue(signers[0].address);
            collateral_value_singer1 = await DataHub.calculateCollateralValue(signers[1].address);

            // console.log("collateral_value_singer0", collateral_value_singer0);
            // console.log("collateral_value_singer1", collateral_value_singer1);
            expect(Number(collateral_value_singer0)).greaterThan(0);
            expect(Number(collateral_value_singer1)).greaterThan(0);

        })
    })

    describe("Functions Simple Test", function () {
        it("updateInterestIndex function test", async function () {
            const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);
            // let temp;
            for (let index = 0; index < 32; index++) {
                await _Interest.updateInterestIndexTest(await USDT_TOKEN.getAddress(), index + 1, index + 1);
            }
            // for (let index = 0; index < 32; index++) {
            //     temp = await _Interest.fetchTimeScaledRateIndex(0, await USDT_TOKEN.getAddress(), index + 1);
            //     // console.log("data", temp.interestRate);
            // }
            // console.log("=======================1=============================");
            // for(let index = 0; index < 16; index++) {
            //     temp = await _Interest.fetchTimeScaledRateIndex(1, await USDT_TOKEN.getAddress(), index + 1);
            //     console.log("data", temp.interestRate);
            // }
            // console.log("=======================2=============================");
            // for(let index = 0; index < 8; index++) {
            //     temp = await _Interest.fetchTimeScaledRateIndex(2, await USDT_TOKEN.getAddress(), index + 1);
            //     console.log("data", temp.interestRate);
            // }
            // console.log("=======================3=============================");
            // for(let index = 0; index < 2; index++) {
            //     temp = await _Interest.fetchTimeScaledRateIndex(3, await USDT_TOKEN.getAddress(), index + 1);
            //     console.log("data", temp.interestRate);
            // }
            // console.log("=======================4=============================");
            // for(let index = 0; index < 1; index++) {
            //     temp = await _Interest.fetchTimeScaledRateIndex(4, await USDT_TOKEN.getAddress(), index + 1);
            //     console.log("data", temp.interestRate);
            // }
            let check_interest;
            check_interest = await _Interest.fetchTimeScaledRateIndex(0, await USDT_TOKEN.getAddress(), 32);
            expect(check_interest.interestRate).equal(31);
            check_interest = await _Interest.fetchTimeScaledRateIndex(1, await USDT_TOKEN.getAddress(), 1);
            expect(check_interest.interestRate).equal(2500000000000000n);
            check_interest = await _Interest.fetchTimeScaledRateIndex(2, await USDT_TOKEN.getAddress(), 1);
            expect(check_interest.interestRate).equal(1250000000000001n);
            check_interest = await _Interest.fetchTimeScaledRateIndex(3, await USDT_TOKEN.getAddress(), 1);
            expect(check_interest.interestRate).equal(625000000000003n);
            check_interest = await _Interest.fetchTimeScaledRateIndex(4, await USDT_TOKEN.getAddress(), 1);
            expect(check_interest.interestRate).equal(312500000000007n);
            // expect(await _Interest.fetchTimeScaledRateIndex(1, await USDT_TOKEN.getAddress(), 1)).equal(2500000000000000n);
            // expect(await _Interest.fetchTimeScaledRateIndex(2, await USDT_TOKEN.getAddress(), 1)).equal(1250000000000001n);
            // expect(await _Interest.fetchTimeScaledRateIndex(3, await USDT_TOKEN.getAddress(), 1)).equal(625000000000003n);

            // expect(await _Interest.fetchTimeScaledRateIndex(4, await USDT_TOKEN.getAddress(), 1)).equal(625000000000003n);
            
        })

        it("calculateAverageCumulativeInterest_fix Function Test", async function () {
            const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);
            // console.log(signers);
            ///////////////////////////////////////////////////////////////////////////////////////////////////////

            /////////////////////////////// DEPOSIT TOKENS //////////////////////////////////
            // console.log("==================== deposit tokens======================");
            // taker deposit amounts 
            // USDT Deposit
            const deposit_amount = 500_000000000000000000n

            const approvalTx = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount);
            await approvalTx.wait();  // Wait for the transaction to be mined

            const transfer = await USDT_TOKEN.transfer(signers[1].address, 20_000_000000000000000000n);
            await transfer.wait();

            expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(0);
           
            await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount)
            // assetInfo[0] of USDT should be same as deposit_amount after deposit
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount);
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
            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(0);

            const approvalTx_2 = await REXE_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount_2);
            await approvalTx_2.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[1]).deposit_token(await REXE_TOKEN.getAddress(), (deposit_amount_2));

            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount_2);
            expect(await REXE_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount_2);
            expect((await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress()))[0]).to.equal(deposit_amount_2); // compare assets in datahub

            // expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);

            // USDT Deposit
            const deposit_amount_3 = 5_000_000000000000000000n

            const approvalTx_3 = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount_3);
            await approvalTx_3.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount_3)

            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount + deposit_amount_3);
            expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount + deposit_amount_3);
            expect((await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount + deposit_amount_3); // compare assets in datahub

            // const originTimestamp = await getTimeStamp(hre.ethers.provider);
            // console.log('Origin timestamp:', originTimestamp);
            // let index = 0;
            for (index = 1; index < 16; index++) {
                await _Interest.setInterestIndex(await USDT_TOKEN.getAddress(), 0, index, 1000 + index * 1000);
            }

            await _Interest.setInterestIndex(await USDT_TOKEN.getAddress(), 1, 1, 3000);

            for (let index = 0; index < 16; index++) {
                rate = (await _Interest.fetchTimeScaledRateIndex(0, await USDT_TOKEN.getAddress(), index)).interestRate;
                // console.log("0 -> rate = " + index + " = ", rate);
            }

            rate = (await _Interest.fetchTimeScaledRateIndex(1, await USDT_TOKEN.getAddress(), 1)).interestRate;
            // console.log("1 -> rate = " + "0" + " = ", rate);
            let avarage_rate = await _Interest.calculateAverageCumulativeInterest_test(2, 12, await USDT_TOKEN.getAddress());
            // console.log("avarage_rate = ", avarage_rate);
            expect(avarage_rate).to.equal(8500);

            avarage_rate = await _Interest.calculateAverageCumulativeInterest_test(0, 12, await USDT_TOKEN.getAddress());
            // console.log("avarage_rate = ", avarage_rate);
            expect(avarage_rate).to.equal(4583);

            avarage_rate = await _Interest.calculateAverageCumulativeInterest_test(7, 12, await USDT_TOKEN.getAddress());
            // console.log("avarage_rate = ", avarage_rate);
            expect(avarage_rate).to.equal(11000n);


            // console.log('All data recorded successfully.');
        })
    })

    describe("Logic Test", function () {
        it("Submit Order Logic Test", async function () {
            return;
            const { signers, Utils, CurrentExchange, deposit_vault, CurrentLiquidator, DataHub, Oracle, _Interest, USDT_TOKEN, REXE_TOKEN } = await loadFixture(deployandInitContracts);
            // console.log(signers);
            ///////////////////////////////////////////////////////////////////////////////////////////////////////

            /////////////////////////////// DEPOSIT TOKENS //////////////////////////////////
            // console.log("==================== deposit tokens======================");
            // taker deposit amounts 
            // USDT Deposit
            const deposit_amount = 500_000000000000000000n

            const approvalTx = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount);
            await approvalTx.wait();  // Wait for the transaction to be mined

            const transfer = await USDT_TOKEN.transfer(signers[1].address, 20_000_000000000000000000n);
            await transfer.wait();

            expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(0);
           
            await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount)
            // assetInfo[0] of USDT should be same as deposit_amount after deposit
            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount);
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
            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(0);

            const approvalTx_2 = await REXE_TOKEN.connect(signers[1]).approve(await deposit_vault.getAddress(), deposit_amount_2);
            await approvalTx_2.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[1]).deposit_token(await REXE_TOKEN.getAddress(), (deposit_amount_2));

            expect((await DataHub.returnAssetLogs(await REXE_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount_2);
            expect(await REXE_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount_2);
            expect((await DataHub.ReadUserData(signers[1].address, await REXE_TOKEN.getAddress()))[0]).to.equal(deposit_amount_2); // compare assets in datahub

            // expect(await USDT_TOKEN.balanceOf(signers[1].address)).to.equal(20_000_000000000000000000n);

            // USDT Deposit
            const deposit_amount_3 = 5_000_000000000000000000n

            const approvalTx_3 = await USDT_TOKEN.approve(await deposit_vault.getAddress(), deposit_amount_3);
            await approvalTx_3.wait();  // Wait for the transaction to be mined
            await deposit_vault.connect(signers[0]).deposit_token(await USDT_TOKEN.getAddress(), deposit_amount_3)

            expect((await DataHub.returnAssetLogs(await USDT_TOKEN.getAddress())).assetInfo[0]).to.equal(deposit_amount + deposit_amount_3);
            expect(await USDT_TOKEN.balanceOf(await deposit_vault.getAddress())).to.equal(deposit_amount + deposit_amount_3);
            expect((await DataHub.ReadUserData(signers[0].address, await USDT_TOKEN.getAddress()))[0]).to.equal(deposit_amount + deposit_amount_3); // compare assets in datahub

            let allData = [];

            for (let i = 0; i <= 53; i++) {

                const scaledTimestamp = originTimestamp + i * 3600;

                setTimeStamp(hre.ethers.provider, network, scaledTimestamp);
                console.log(`Loop ${i}: Set timestamp to ${scaledTimestamp}`);

                const masscharges_usdt = await _Interest.chargeMassinterest(await USDT_TOKEN.getAddress()); // increase borrow amount
                await masscharges_usdt.wait(); // Wait for the transaction to be mined

                const masscharges_rexe = await _Interest.chargeMassinterest(await REXE_TOKEN.getAddress()); // increase borrow amount
                await masscharges_rexe.wait(); // Wait for the transaction to be mined
            }

            console.log('All data recorded successfully.');
        })
    })
})
