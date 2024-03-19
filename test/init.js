const hre = require("hardhat");
const OracleABI  = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/REX_EXCHANGE.json") 
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json") 
const DataHubAbi  = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")

describe("Init the contracts", function () {
  it("Init token market ", async function () {

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
    
    const ETHprice ="2597000000000000000000";
         
        const ETHinitialMarginFee = "50000000000000000"
        const ETHliquidationFee =  "50000000000000000"
        const ETHinitialMarginRequirement =  "200000000000000000"
        const ETHMaintenanceMarginRequirement =  "100000000000000000"
        const ETHoptimalBorrowProportion =  "700000000000000000"
        const ETHmaximumBorrowProportion = "1000000000000000000"
        const ETH_interestRate = "5000000000000000"
        const ETH_interestRateInfo = ["5000000000000000","100000000000000000","1000000000000000000"]
    
    const wBTC = "0xf18DC65c89BB097a5Da0f4fAdD8bfA2ADEc74Cf9"
    
    const wBTCprice = "46100000000000000000000";
         
        const wBTCinitialMarginFee = "50000000000000000"
        const wBTCliquidationFee = "50000000000000000"
        const wBTCinitialMarginRequirement = "200000000000000000"
        const wBTCMaintenanceMarginRequirement =  "100000000000000000"
        const wBTCoptimalBorrowProportion =  "700000000000000000"
        const wBTCmaximumBorrowProportion = "1000000000000000000"
        const wBTC_interestRate = "5000000000000000"
        const wBTC_interestRateInfo = ["5000000000000000","100000000000000000","1000000000000000000"]
    
    const MATIC = "0x661a3a439B25B9aD39f15289D668e6607c0B336d"
    
    const MATICprice = "910000000000000000";
         
        const MATICinitialMarginFee = "50000000000000000"
        const MATICliquidationFee = "75000000000000000"
        const MATICinitialMarginRequirement = "250000000000000000"
        const MATICMaintenanceMarginRequirement = "125000000000000000"
        const MATICoptimalBorrowProportion = "700000000000000000"
        const MATICmaximumBorrowProportion = "1000000000000000000"
        const MATIC_interestRate ="5000000000000000"
        const MATIC_interestRateInfo = ["5000000000000000","100000000000000000","1000000000000000000"]
      /*
        REX Library deployed to 0x8cc91C79C9Bd871a02adde1F802Bd320fa0F83f7
        Datahub deployed to 0xE620314E429835d957507855533cC9effCD02813
        Deposit Vault deployed to 0x47393854E95ccCd832aC9c3f71b23B0edf7C9382
        Oracle deployed to 0x5d6D5a14d0f187A7d6876E7F1196D56f0de7958F
        Utils deployed to 0x51C41a55f2fA1bC7cbB4581b23921409A3B9a3ee
        Exchange deployed to 0x705a5c604B1F97E1AD4e4041A7C04960BD1b1F26


    const ex = "0x064F0138589BcECA0dA3e3dD5A3B64AC649F9bc0"
    const DH = "0xC82bc3d3baC3478213D8c9D5ab0da5e9cE64bEf4"
    const DV = "0x56AAB785048E983B9AA2401A957dDC19465ECe09"
    const oracle = "0x67Af449524bbD80E0e91D7FF0f7A8756EC6304c9"

    const util = "0x07a3ADf3c555E6E47E58F14db61dD44ed046629f"

    ROUND 2 SAVED CONTRACTS
    const ex = "0x705a5c604B1F97E1AD4e4041A7C04960BD1b1F26"
    const DH = "0xE620314E429835d957507855533cC9effCD02813"
    const DV = "0x47393854E95ccCd832aC9c3f71b23B0edf7C9382"
    const oracle = "0x5d6D5a14d0f187A7d6876E7F1196D56f0de7958F"
    const util = "0x51C41a55f2fA1bC7cbB4581b23921409A3B9a3ee"


        const ex = "0x76258A2Ef137f3C903E2E8877628694404e6ad32"
    const DH = "0xa5E250aA2a3A6cC079924c157Cd6099e468AeD0C"
    const DV = "0x9F4EFABfE756Eb498018BFC12F486990794fc14C"
    const oracle = "0x1F00917Cb18fFB39A5Cb3250c818f35c23F6C03c"
    const util = "0x0238F177027b9B1385aBe0ae046a1ED0F7ED1b2c"

        const ex = "0xf3ac80cfB78b665D9F651d4F7556273c605C9f0B"
    const DH = "0x2c4c93998aF28007F63F57324cEaF51D0fB799c5"
    const DV = "0x7Ab97E149Cd3E1d073eb5669810bA088a7710A78"
    const oracle = "0xca2d202758c4800D525bB451379b4d4A46F41622"
    const util = "0x54167fedfE5400c26aDc06deADf48592E009D696"


    REX Library deployed to 0x2B532D1591f938eDaa989cF586FD9b1C1605a331
Datahub deployed to 0x4c3379ffe6D9c1C1688055E6e517936f2B5aCDd9
Deposit Vault deployed to 0x52859A83276795FbDDAA1870307618e7F35af9ab
Oracle deployed to 0x76CA5A2FAe0DEA3ae949b26E12Ce698E9435E311
Utils deployed to 0x91fc8158B7d66595CC6D629DDc69dc2bA104bE93
Exchange deployed to 0xBBcFA022F0b8560D8248507839C2f146fA5F66B6

    const ex = "0xBBcFA022F0b8560D8248507839C2f146fA5F66B6"
    const DH = "0x4c3379ffe6D9c1C1688055E6e517936f2B5aCDd9"
    const DV = "0x52859A83276795FbDDAA1870307618e7F35af9ab"
    const oracle = "0x76CA5A2FAe0DEA3ae949b26E12Ce698E9435E311"
    const util = "0x91fc8158B7d66595CC6D629DDc69dc2bA104bE93"


Deploying contracts with the account: 0x8d23Bd68E5c095B7A1999E090B2F9c20114CbBb4
REX Library deployed to 0xa5683d127743Dbc60A265E3ca3857de3C2F5e395
Datahub deployed to 0xaB944652F0dB83968E9864037b2F0F966d2131f3
Deposit Vault deployed to 0xfe2B69b00fb4560f68B83a34633f5bC8B180D1f9
Oracle deployed to 0x2987e03EF6Fc09A7a3C522C4082A1E37dda62383
Utils deployed to 0x49886079A26412c830025003403EE0B1fc47A557
Exchange deployed to 0x829a929b1d5c9CE0fF480E107bBDF6Aa434DFc72

    const ex = "0x829a929b1d5c9CE0fF480E107bBDF6Aa434DFc72"
    const DH = "0xaB944652F0dB83968E9864037b2F0F966d2131f3"
    const DV = "0xfe2B69b00fb4560f68B83a34633f5bC8B180D1f9"
    const oracle = "0x2987e03EF6Fc09A7a3C522C4082A1E37dda62383"
    const util = "0x49886079A26412c830025003403EE0B1fc47A557"

        const ex = "0x58fd5BB2e41376f0f8cAE6105B6EC8E02125F2C5"
    const DH = "0xb494f7ca9bfDf9490DDaEC26809F7e9A1F603Fb4"
    const DV = "0x9C598ba04c364C294E0100c3437036ae87b47726"
    const oracle = "0x586dd60Abc9c298Fa891a12F696C23A3796960b6"
    const util = "0x045C3e05CB6b446f9d5D85046CdAafA6De7b840f"
*/

const ex = "0x51A18FeE98838D6D056De3df50DB70AbA60236A4"
const DH = "0xeC449bEDE2B6ef411B2c16fc5E71755ec5d9958a"
const DV = "0xc229bf510DE89AB60cEAD17dFD2F335897bb5Ab8"
const oracle = "0xa4601c91Aa948a3223375a17d3F3A35CC6484ef5"
const util = "0x4dC3dd7858c8d1347B30923E4Fb0E04a27D33082"
const liq = "0xAD6dECc5dA0E5E2F1Be76116E947aF1953274aF6"
const interest = "0x44F5a094dCF5ADa14EAEb31932070BB044ACd981"

    const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

    console.log("INIT with the account:", deployer.address);

    const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

    const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

    const utils  = new hre.ethers.Contract(util, utilABI.abi, deployer);

    const SETUP = await utils.AlterExchange(ex);


    SETUP.wait()

    const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

    const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle, util, interest);

    SETUPEX.wait()

    const setup = await DataHub.AlterAdminRoles(DV, ex, oracle,interest);

    setup.wait();

    const oraclesetup = await Oracle.AlterExecutor(ex);

    oraclesetup.wait();

    const CurrentLiquidator  = new hre.ethers.Contract(liq, LiquidatorAbi.abi, deployer);

    const liqSetup = await CurrentLiquidator.AlterAdmins(ex);
  
    liqSetup.wait();

    const _Interest = new hre.ethers.Contract(interest, InterestAbi.abi, deployer);


    const interestSetup = await _Interest.AlterAdmins( ex, DH);

    interestSetup.wait();

    const USDT_init_transaction = await DataHub.InitTokenMarket(USDT, USDTprice,colval, USDTinitialMarginFee, USDTliquidationFee, USDTinitialMarginRequirement, USDTMaintenanceMarginRequirement, USDToptimalBorrowProportion, USDTmaximumBorrowProportion);


    USDT_init_transaction.wait();


    const REXE_init_transaction = await DataHub.InitTokenMarket(REXE, REXEprice,colval, REXEinitialMarginFee, REXEliquidationFee, REXEinitialMarginRequirement, REXEMaintenanceMarginRequirement, REXEoptimalBorrowProportion, REXEmaximumBorrowProportion);

    REXE_init_transaction.wait();

    const ETH_init_transaction = await DataHub.InitTokenMarket(ETH, ETHprice,colval, ETHinitialMarginFee, ETHliquidationFee, ETHinitialMarginRequirement, ETHMaintenanceMarginRequirement, ETHoptimalBorrowProportion, ETHmaximumBorrowProportion);

    ETH_init_transaction.wait();

    const MATIC_init_transaction = await DataHub.InitTokenMarket(MATIC, MATICprice, colval, MATICinitialMarginFee, MATICliquidationFee, MATICinitialMarginRequirement, MATICMaintenanceMarginRequirement, MATICoptimalBorrowProportion, MATICmaximumBorrowProportion);

    MATIC_init_transaction.wait();

    const wBTC_init_transaction = await DataHub.InitTokenMarket(wBTC, wBTCprice, colval, wBTCinitialMarginFee, wBTCliquidationFee, wBTCinitialMarginRequirement, wBTCMaintenanceMarginRequirement,wBTCoptimalBorrowProportion, wBTCmaximumBorrowProportion);

    wBTC_init_transaction.wait();


  });
});
