const hre = require("hardhat");
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")

async function main(){

        /*
Deploying contracts with the account: 0x19E75eD87d138B18263AfE40f7C16E4a5ceCB585 undefined
EVO Library deployed to 0xf3c8298Ef7Ec73ab821e0Cb46368145013d43F60
Datahub deployed to 0xfc3f0E8eaEB9Ba9C52E84fc777Dd41964eAC4252
Interest deployed to 0xf1d2e67C64Cbb486BdC07955fCCFD1F635f9483C
Deposit Vault deployed to 0xa9d870a4480F8E0093cfbc1632F1eee32Df89115
Oracle deployed to 0xA0F9a39d656724a65561980c44e52bb80c232F79
Utils deployed to 0x3138C2F7723EA5a9748D59d6FADC5627Fe916749
Liquidator deployed to 0x8dF103078B500A89E72f95a02a02030Cfe7Ca080
Exchange deployed to 0x87e02373945F4DBD9cb4f640CF59baaf86327A36


// below is the updated suite with our new changes to hopefully fix errr thing

EVO Library deployed to 0x57E52102561799B60Ebb5c8Cea8bef040C19cb5a
Datahub deployed to 0x9dEB2F4A64b7E56e08fB9d065AA515643Ec04B1b
Interest deployed to 0x85c8b7e19045a528c89831bD93a47375931738f2
Deposit Vault deployed to 0x259ca2d085Bdc9Ab4C19D834781f2De7a44C388a
Oracle deployed to 0xb06ff8274F31ba7bFCDC734b810B55C48dE87C18
Utils deployed to 0x453B0471Ccc75382697ED645ee8Ede742DD09D50
Liquidator deployed to 0xFe1cC78055F628eB067FE696fB2a8dA57C3C6001
Exchange deployed to 0x4E1Dc2D90E81Ad889054Ef2668B5Ab5fDDdf23bf

        */

        const tradeFees = [0, 0];

        const USDT = "0xaBAD60e4e01547E2975a96426399a5a0578223Cb"

        const USDTprice = "1000000000000000000"

        const colval = "1000000000000000000"

        const USDTinitialMarginFee = "5000000000000000" // 0.5% //0.05 (5*16)
        const USDTliquidationFee = "30000000000000000"//( 3**17) was 30
        const USDTinitialMarginRequirement = "200000000000000000"//( 2**18) was 200
        const USDTMaintenanceMarginRequirement = "100000000000000000" // .1 ( 10*17)
        const USDToptimalBorrowProportion = "700000000000000000"//( 7**18) was 700
        const USDTmaximumBorrowProportion = "1000000000000000000"//( 10**18) was 1000
        const USDTInterestRate = "5000000000000000"//( 5**16) was 5
        const USDT_interestRateInfo = ["5000000000000000", "150000000000000000", "1000000000000000000"] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000



        const REXE = "0x1E67a46D59527B8a77D1eC7C6EEc0B06FcF31E28"

        const REXEprice = "500000000000000000";

        const REXEinitialMarginFee = "10000000000000000";
        const REXEliquidationFee = "100000000000000000";
        const REXEinitialMarginRequirement = "500000000000000000"
        const REXEMaintenanceMarginRequirement = "250000000000000000"
        const REXEoptimalBorrowProportion = "700000000000000000"
        const REXEmaximumBorrowProportion = "1000000000000000000"
        const REXEInterestRate = "5000000000000000"
        const REXEinterestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]



        const ETH = "0xa2A629a0b4F7216A6B3b7632C96Cb886d0A171b6"

        const ETHprice = "2597000000000000000000";

        const ETHinitialMarginFee = "50000000000000000"
        const ETHliquidationFee = "50000000000000000"
        const ETHinitialMarginRequirement = "200000000000000000"
        const ETHMaintenanceMarginRequirement = "100000000000000000"
        const ETHoptimalBorrowProportion = "700000000000000000"
        const ETHmaximumBorrowProportion = "1000000000000000000"
        const ETH_interestRate = "5000000000000000"
        const ETH_interestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]

        const wBTC = "0xf18DC65c89BB097a5Da0f4fAdD8bfA2ADEc74Cf9"

        const wBTCprice = "46100000000000000000000";

        const wBTCinitialMarginFee = "50000000000000000"
        const wBTCliquidationFee = "50000000000000000"
        const wBTCinitialMarginRequirement = "200000000000000000"
        const wBTCMaintenanceMarginRequirement = "100000000000000000"
        const wBTCoptimalBorrowProportion = "700000000000000000"
        const wBTCmaximumBorrowProportion = "1000000000000000000"
        const wBTC_interestRate = "5000000000000000"
        const wBTC_interestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]

        const MATIC = "0x661a3a439B25B9aD39f15289D668e6607c0B336d"

        const MATICprice = "910000000000000000";

        const MATICinitialMarginFee = "50000000000000000"
        const MATICliquidationFee = "75000000000000000"
        const MATICinitialMarginRequirement = "250000000000000000"
        const MATICMaintenanceMarginRequirement = "125000000000000000"
        const MATICoptimalBorrowProportion = "700000000000000000"
        const MATICmaximumBorrowProportion = "1000000000000000000"
        const MATIC_interestRate = "5000000000000000"
        const MATIC_interestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]
        /*
Deploying contracts with the account: 0x19E75eD87d138B18263AfE40f7C16E4a5ceCB585 undefined
EVO Library deployed to 0xf3c8298Ef7Ec73ab821e0Cb46368145013d43F60
Datahub deployed to 0xfc3f0E8eaEB9Ba9C52E84fc777Dd41964eAC4252
Interest deployed to 0xf1d2e67C64Cbb486BdC07955fCCFD1F635f9483C
Deposit Vault deployed to 0xa9d870a4480F8E0093cfbc1632F1eee32Df89115
Oracle deployed to 0xA0F9a39d656724a65561980c44e52bb80c232F79
Utils deployed to 0x3138C2F7723EA5a9748D59d6FADC5627Fe916749
Liquidator deployed to 0x8dF103078B500A89E72f95a02a02030Cfe7Ca080
Exchange deployed to 0x87e02373945F4DBD9cb4f640CF59baaf86327A36

        // original suite 
        const ex = "0x87e02373945F4DBD9cb4f640CF59baaf86327A36"
        const DH = "0xfc3f0E8eaEB9Ba9C52E84fc777Dd41964eAC4252"
        const DV = "0xa9d870a4480F8E0093cfbc1632F1eee32Df89115"
        const oracle = "0xA0F9a39d656724a65561980c44e52bb80c232F79"
        const util = "0x3138C2F7723EA5a9748D59d6FADC5627Fe916749"
        const interest = "0xf1d2e67C64Cbb486BdC07955fCCFD1F635f9483C"
        const liq = "0x8dF103078B500A89E72f95a02a02030Cfe7Ca080"



EVO Library deployed to 0x57E52102561799B60Ebb5c8Cea8bef040C19cb5a
Datahub deployed to 0x9dEB2F4A64b7E56e08fB9d065AA515643Ec04B1b
Interest deployed to 0x85c8b7e19045a528c89831bD93a47375931738f2
Deposit Vault deployed to 0x259ca2d085Bdc9Ab4C19D834781f2De7a44C388a
Oracle deployed to 0xb06ff8274F31ba7bFCDC734b810B55C48dE87C18
Utils deployed to 0x453B0471Ccc75382697ED645ee8Ede742DD09D50
Liquidator deployed to 0xFe1cC78055F628eB067FE696fB2a8dA57C3C6001
Exchange deployed to 0x4E1Dc2D90E81Ad889054Ef2668B5Ab5fDDdf23bf

        */
        const ex = "0x4E1Dc2D90E81Ad889054Ef2668B5Ab5fDDdf23bf"
        const DH = "0x9dEB2F4A64b7E56e08fB9d065AA515643Ec04B1b"
        const DV = "0x259ca2d085Bdc9Ab4C19D834781f2De7a44C388a"
        const oracle = "0xb06ff8274F31ba7bFCDC734b810B55C48dE87C18"
        const util = "0x453B0471Ccc75382697ED645ee8Ede742DD09D50"
        const interest = "0x85c8b7e19045a528c89831bD93a47375931738f2"
        const liq = "0xFe1cC78055F628eB067FE696fB2a8dA57C3C6001"

        const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

        console.log("INIT with the account:", deployer.address);

        const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

        const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

        const DepositVault = new hre.ethers.Contract(DV, depositABI.abi, deployer);

        const Utils = new hre.ethers.Contract(util, utilABI.abi, deployer);

        const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

        const _Interest = new hre.ethers.Contract(interest, InterestAbi.abi, deployer);

        const CurrentLiquidator = new hre.ethers.Contract(liq, LiquidatorAbi.abi, deployer);


        const SETUP = await Utils.alterAdminRoles(DH, DV, oracle, interest, liq, ex);

        SETUP.wait()



        const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle, util, interest, liq);

   
        SETUPEX.wait()


        const setupDV = await DepositVault.alterAdminRoles(DH, ex, interest)

        setupDV.wait();


        const liqSetup = await CurrentLiquidator.alterAdminRoles(ex);

        liqSetup.wait();



        const setup = await DataHub.alterAdminRoles(DV, ex, oracle, interest, util);

        setup.wait();


        const oraclesetup = await Oracle.alterAdminRoles(ex, DH, DV);

        oraclesetup.wait();



        const interestSetup = await _Interest.alterAdminRoles(DH, ex, DV, util);
   

        interestSetup.wait();

        console.log("Contract Admin Roles configured")


        const InitRatesREXE = await _Interest.initInterest(REXE, 1, REXEinterestRateInfo, REXEInterestRate)
        const InitRatesUSDT = await _Interest.initInterest(USDT, 1, USDT_interestRateInfo, USDTInterestRate)

        const InitRatesETH = await _Interest.initInterest(ETH, 1, ETH_interestRateInfo, ETH_interestRate)
        const InitRateswbtc = await _Interest.initInterest(wBTC, 1, wBTC_interestRateInfo, wBTC_interestRate)
        const InitRatesmatic = await _Interest.initInterest(MATIC, 1, MATIC_interestRateInfo, MATIC_interestRate)

        InitRatesETH.wait();
        InitRateswbtc.wait();
        InitRatesmatic.wait();

        InitRatesREXE.wait();
        InitRatesUSDT.wait();

        console.log("Interest Rates configured")



        const USDT_init_transaction = await DataHub.InitTokenMarket(USDT, USDTprice, colval, tradeFees, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);


        USDT_init_transaction.wait();


        const REXE_init_transaction = await DataHub.InitTokenMarket(REXE, REXEprice, colval, tradeFees, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);

        REXE_init_transaction.wait();

        const ETH_init_transaction = await DataHub.InitTokenMarket(ETH, ETHprice, colval, tradeFees, ETHinitialMarginFee, ETHliquidationFee, ETHinitialMarginRequirement, ETHMaintenanceMarginRequirement, ETHoptimalBorrowProportion, ETHmaximumBorrowProportion);

        ETH_init_transaction.wait();

        const MATIC_init_transaction = await DataHub.InitTokenMarket(MATIC, MATICprice, colval, tradeFees, MATICinitialMarginFee, MATICliquidationFee, MATICinitialMarginRequirement, MATICMaintenanceMarginRequirement, MATICoptimalBorrowProportion, MATICmaximumBorrowProportion);

        MATIC_init_transaction.wait();

        const wBTC_init_transaction = await DataHub.InitTokenMarket(wBTC, wBTCprice, colval, tradeFees, wBTCinitialMarginFee, wBTCliquidationFee, wBTCinitialMarginRequirement, wBTCMaintenanceMarginRequirement, wBTCoptimalBorrowProportion, wBTCmaximumBorrowProportion);

        wBTC_init_transaction.wait();

        console.log("Initialization complete")


}main()