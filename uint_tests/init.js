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

    const ETH = "0xe5F312BFd45f56e0b03318Eae57064214519d379"
    
    const ETHprice ="2597000000000000000000";
         
        const ETHinitialMarginFee = "50000000000000000"
        const ETHliquidationFee =  "50000000000000000"
        const ETHinitialMarginRequirement =  "200000000000000000"
        const ETHMaintenanceMarginRequirement =  "100000000000000000"
        const ETHoptimalBorrowProportion =  "700000000000000000"
        const ETHmaximumBorrowProportion = "1000000000000000000"
        const ETH_interestRate = "5000000000000000"
        const ETH_interestRateInfo = ["5000000000000000","100000000000000000","1000000000000000000"]
    
    const wBTC = "0xCDcDCc1034fCE58bd72c3462f13E60B7A8f46c3f"
    
    const wBTCprice = "46100000000000000000000";
         
        const wBTCinitialMarginFee = "50000000000000000"
        const wBTCliquidationFee = "50000000000000000"
        const wBTCinitialMarginRequirement = "200000000000000000"
        const wBTCMaintenanceMarginRequirement =  "100000000000000000"
        const wBTCoptimalBorrowProportion =  "700000000000000000"
        const wBTCmaximumBorrowProportion = "1000000000000000000"
        const wBTC_interestRate = "5000000000000000"
        const wBTC_interestRateInfo = ["5000000000000000","100000000000000000","1000000000000000000"]
    
    const MATIC = "0x8AE0942E64C18dd8c5C075c5c4dc80F318A7a97E"
    
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
*/

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

    const ETH_init_transaction = await DataHub.InitTokenMarket(ETH, ETHprice, ETHinitialMarginFee, ETHliquidationFee, ETHinitialMarginRequirement, ETHMaintenanceMarginRequirement, ETHoptimalBorrowProportion, ETHmaximumBorrowProportion,ETH_interestRate, ETH_interestRateInfo);

    ETH_init_transaction.wait();

    const MATIC_init_transaction = await DataHub.InitTokenMarket(MATIC, MATICprice, MATICinitialMarginFee, MATICliquidationFee, MATICinitialMarginRequirement, MATICMaintenanceMarginRequirement, MATICoptimalBorrowProportion, MATICmaximumBorrowProportion,MATIC_interestRate, MATIC_interestRateInfo);

    MATIC_init_transaction.wait();

    const wBTC_init_transaction = await DataHub.InitTokenMarket(wBTC, wBTCprice, wBTCinitialMarginFee, wBTCliquidationFee, wBTCinitialMarginRequirement, wBTCMaintenanceMarginRequirement,wBTCoptimalBorrowProportion, wBTCmaximumBorrowProportion,wBTC_interestRate, wBTC_interestRateInfo);

    wBTC_init_transaction.wait();


  });
});
