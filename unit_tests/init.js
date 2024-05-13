const hre = require("hardhat");
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")

describe("Init the contracts", function () {
  it("Init token market ", async function () {

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
    const REXEliquidationFee = "10000000000000000";
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
  
    const ex = "0xcC19743D952e144E17f144EDcEf4ba0E7046008a"
    const DH = "0x213b8Bd7c264AF29Ba500ecC03D0D8a617B30168"
    const DV = "0x9F7c609C7d42fa510c4375b1DAd7dd5ED17F74F0"
    const oracle = "0x0C8dca97ac7165B60d8539596Bb65E48D784e2fe"
    const util = "0xfBD0b27dF86e3Cf781a63a6A924Cbb78B0dFe9Ad"
    const interest = "0xfBD0b27dF86e3Cf781a63a6A924Cbb78B0dFe9Ad"
    const liq = "0xfBD0b27dF86e3Cf781a63a6A924Cbb78B0dFe9Ad"

    const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

    console.log("INIT with the account:", deployer.address);

    const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

    const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

    const deposit_vault = new hre.ethers.Contract(DV,depositABI.abi, deployer)

    const Utils  = new hre.ethers.Contract(util, utilABI.abi, deployer);

    const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

    const _Interest = new hre.ethers.Contract(interest, InterestAbi.abi, deployer);

    const CurrentLiquidator = new hre.ethers.Contract(liq, LiquidatorAbi.abi, deployer);


    const SETUP = await Utils.alterAdminRoles(DH, DV, oracle, interest, liq, ex);

    SETUP.wait()




    const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle,util, interest, liq);

    SETUPEX.wait()




    const setupDV = await deposit_vault.alterAdminRoles(DH, ex, interest)

    setupDV.wait();


    const liqSetup = await CurrentLiquidator.alterAdminRoles(ex);

    liqSetup.wait();



    const setup = await DataHub.alterAdminRoles(DV, ex,oracle, interest, util);

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


  
    const USDT_init_transaction = await DataHub.InitTokenMarket(USDT, USDTprice, colval,tradeFees, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);
  
  
    USDT_init_transaction.wait();
  
  
    const REXE_init_transaction = await DataHub.InitTokenMarket(REXE, REXEprice, colval,tradeFees, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);
  
    REXE_init_transaction.wait();
  
    const ETH_init_transaction = await DataHub.InitTokenMarket(ETH, ETHprice, colval,tradeFees, ETHinitialMarginFee, ETHliquidationFee, ETHinitialMarginRequirement, ETHMaintenanceMarginRequirement, ETHoptimalBorrowProportion, ETHmaximumBorrowProportion);
  
    ETH_init_transaction.wait();
  
    const MATIC_init_transaction = await DataHub.InitTokenMarket(MATIC, MATICprice, colval,tradeFees, MATICinitialMarginFee, MATICliquidationFee, MATICinitialMarginRequirement, MATICMaintenanceMarginRequirement, MATICoptimalBorrowProportion, MATICmaximumBorrowProportion);
  
    MATIC_init_transaction.wait();
  
    const wBTC_init_transaction = await DataHub.InitTokenMarket(wBTC, wBTCprice, colval,tradeFees, wBTCinitialMarginFee, wBTCliquidationFee, wBTCinitialMarginRequirement, wBTCMaintenanceMarginRequirement, wBTCoptimalBorrowProportion, wBTCmaximumBorrowProportion);
  
    wBTC_init_transaction.wait();

    console.log("Initialization complete")


  });
});
