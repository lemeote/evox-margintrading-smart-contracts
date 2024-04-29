const hre = require("hardhat");
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")

async function main() {
/*
  const ex = "0x82C19528944441bF4703C0f4bb4356521eC526ff"
  const DH = "0xb6f53a0D9932281e38056961A7afAecD6846418D"
  /// const DV = "0x1407A3e2Cbd3dA47E57f9260580Cf75DEE0A53C0"
  const DV = "0x54f8DA3DE94173E354B562C8e8A736612c1010fD"
  const oracle = "0x2d69e64bC23F8af2172F1c434A15B20a6c31e55E"
  const util = "0x156d790B12864E071A0b0eE8202C64079D346687"
  const liq = "0xFB31DcD03F592D967da1660498A828Dc3e87aCc7"
  //  const interest = "0xaF8749DA37232f2bbf3375642079841DCeEE0a4A"
  const interest = "0xB1b9998d2374d4FE5A0400F59e8D3eC3e83c8E33"
*/
const ex = "0x65EC35b629308b91D5B3c0a57499c864e49Bd97F"
const DH = "0x128588e8c8F7Bc53d275bBb8a37Bb0A5085015Ba"
/// const DV = "0x1407A3e2Cbd3dA47E57f9260580Cf75DEE0A53C0"
const DV = "0x77d79d147078579c8614493cF07e0fe3432C5dEc"
const oracle = "0xF64Ce1443ED4947EaB04a6A1ad5213Fcb1911EcD"
const util = "0x75024eB22A09abcDa1a89621fd8F3801305432CF"
const liq = "0xE4cFE709B5922DaAB8DDCf004897022066dF2943"
//  const interest = "0xaF8749DA37232f2bbf3375642079841DCeEE0a4A"
const interest = "0xd2C51851d7f438C2B9fE9Eb149Ad3481c80E4d18"
  //REX Library deployed to 0x71b761EA084e36DEca3d06ea30EA1D2C118a31B5
  //Interest deployed to 0xd2C51851d7f438C2B9fE9Eb149Ad3481c80E4d18
  //Datahub deployed to 0x128588e8c8F7Bc53d275bBb8a37Bb0A5085015Ba
 // Deposit Vault deployed to 0x77d79d147078579c8614493cF07e0fe3432C5dEc
  //Oracle deployed to 0xF64Ce1443ED4947EaB04a6A1ad5213Fcb1911EcD
  //Utils deployed to 0x75024eB22A09abcDa1a89621fd8F3801305432CF
 // Liquidator deployed to 0xE4cFE709B5922DaAB8DDCf004897022066dF2943
 // Exchange deployed to 0x65EC35b629308b91D5B3c0a57499c864e49Bd97F


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


  //
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


  const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

  console.log("INIT with the account:", deployer.address);

  const _Interest = new hre.ethers.Contract(interest, InterestAbi.abi, deployer);
 
  const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

  const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

  const DepositVault = new hre.ethers.Contract(DV, depositABI.abi, deployer);

  const utils = new hre.ethers.Contract(util, utilABI.abi, deployer);

  const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

  const setupDH = await DataHub.alterAdminRoles(DV, ex, oracle, interest);

  console.log("Setup interest completed");

  setupDH.wait();

  const setupDV = await DepositVault.alterAdmins(DH, ex, interest);

  setupDV.wait();

  console.log("Setup dv completed");

  const setupUtils = await utils.alterExchange(ex);


  setupUtils.wait()



  const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle, util, interest);

  SETUPEX.wait()


  const oraclesetup = await Oracle.alterAdminRoles(
    DV,
    ex,
    DH)

  oraclesetup.wait();

  const CurrentLiquidator = new hre.ethers.Contract(liq, LiquidatorAbi.abi, deployer);

  const liqSetup = await CurrentLiquidator.AlterAdmins(ex);

  liqSetup.wait();



  const interestSetup = await _Interest.alterAdminRoles(ex, DH, DV);
  interestSetup.wait();





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


  const USDT_init_transaction = await DataHub.InitTokenMarket(USDT, USDTprice, colval, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);


  USDT_init_transaction.wait();


  const REXE_init_transaction = await DataHub.InitTokenMarket(REXE, REXEprice, colval, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);

  REXE_init_transaction.wait();

  const ETH_init_transaction = await DataHub.InitTokenMarket(ETH, ETHprice, colval, ETHinitialMarginFee, ETHliquidationFee, ETHinitialMarginRequirement, ETHMaintenanceMarginRequirement, ETHoptimalBorrowProportion, ETHmaximumBorrowProportion);

  ETH_init_transaction.wait();

  const MATIC_init_transaction = await DataHub.InitTokenMarket(MATIC, MATICprice, colval, MATICinitialMarginFee, MATICliquidationFee, MATICinitialMarginRequirement, MATICMaintenanceMarginRequirement, MATICoptimalBorrowProportion, MATICmaximumBorrowProportion);

  MATIC_init_transaction.wait();

  const wBTC_init_transaction = await DataHub.InitTokenMarket(wBTC, wBTCprice, colval, wBTCinitialMarginFee, wBTCliquidationFee, wBTCinitialMarginRequirement, wBTCMaintenanceMarginRequirement, wBTCoptimalBorrowProportion, wBTCmaximumBorrowProportion);

  wBTC_init_transaction.wait();

} main();
