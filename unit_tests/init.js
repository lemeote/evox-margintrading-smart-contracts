const hre = require("hardhat");
const OracleABI  = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/REX_EXCHANGE.json") 
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json") 
const DataHubAbi  = require("../artifacts/contracts/datahub.sol/DataHub.json");

describe("Init the contracts", function () {
  it("Init token market ", async function () {

    const USDT = "0xdfc6a3f2d7daff1626Ba6c32B79bEE1e1d6259F0"

    const USDTprice = "1000000000000000000"
    
    const USDTinitialMarginFee = "5000000000000000" // 0.5% //0.05 (5*16)
    const USDTliquidationFee = "30000000000000000"//( 3**17) was 30
    const USDTinitialMarginRequirement = "200000000000000000"//( 2**18) was 200
    const USDTMaintenanceMarginRequirement = "100000000000000000" // .1 ( 10*17)
    const USDToptimalBorrowProportion = "700000000000000000"//( 7**18) was 700
    const USDTmaximumBorrowProportion = "1000000000000000000"//( 10**18) was 1000
    const USDTInterestRate = "5000000000000000"//( 5**16) was 5
    const USDT_interestRateInfo = ["5000000000000000","150000000000000000","1000000000000000000"] //( 5**16) was 5, 150**16 was 150, 1000 **16 was 1000


    const REXE = "0xEb008acbb5961C2a82123B3d04aBAD0e0EEe9266"

    const REXEprice = "500000000000000000";
         
    const REXEinitialMarginFee = "10000000000000000";
    const REXEliquidationFee = "10000000000000000";
    const REXEinitialMarginRequirement = "500000000000000000"
    const REXEMaintenanceMarginRequirement =  "250000000000000000"
    const REXEoptimalBorrowProportion =  "700000000000000000"
    const REXEmaximumBorrowProportion =  "1000000000000000000"
    const REXEInterestRate = "5000000000000000"
    const REXEinterestRateInfo = ["5000000000000000","100000000000000000","1000000000000000000"]

    const ex = "0xcC19743D952e144E17f144EDcEf4ba0E7046008a"
    const DH = "0x213b8Bd7c264AF29Ba500ecC03D0D8a617B30168"
    const DV = "0x9F7c609C7d42fa510c4375b1DAd7dd5ED17F74F0"
    const oracle = "0x0C8dca97ac7165B60d8539596Bb65E48D784e2fe"
    const util = "0xfBD0b27dF86e3Cf781a63a6A924Cbb78B0dFe9Ad"

    const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

    console.log("INIT with the account:", deployer.address);

    const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

    const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

    const utils  = new hre.ethers.Contract(util, utilABI.abi, deployer);

    const SETUP = await utils.AlterExchange(ex);


    SETUP.wait()

    const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

    const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle, util);

    SETUPEX.wait()

    
    const setup = await DataHub.AlterAdminRoles(DV, ex, oracle);

    setup.wait();

    const oraclesetup = await Oracle.AlterExecutor(ex);

    oraclesetup.wait();

    const USDT_init_transaction = await DataHub.InitTokenMarket(USDT, USDTprice, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion,USDTInterestRate, USDT_interestRateInfo);


    USDT_init_transaction.wait();


    const REXE_init_transaction = await DataHub.InitTokenMarket(REXE, REXEprice, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion,REXEInterestRate, REXEinterestRateInfo);

    REXE_init_transaction.wait();

  });
});
