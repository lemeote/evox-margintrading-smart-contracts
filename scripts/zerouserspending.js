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

        */

        const tradeFees = [0, 0];

        const USDT = "0xaBAD60e4e01547E2975a96426399a5a0578223Cb"

        const USDTprice = "1000000000000000000"

        const colval = "1000000000000000000"

        const USDTinitialMarginFee = "5000000000000000" // 0.5% //0.05 (5*16)
        const USDTliquidationFee = "100000000000000000"//( 3**17) was 30
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
        const ETHliquidationFee = "100000000000000000"
        const ETHinitialMarginRequirement = "200000000000000000"
        const ETHMaintenanceMarginRequirement = "100000000000000000"
        const ETHoptimalBorrowProportion = "700000000000000000"
        const ETHmaximumBorrowProportion = "1000000000000000000"
        const ETH_interestRate = "5000000000000000"
        const ETH_interestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]

        const wBTC = "0xf18DC65c89BB097a5Da0f4fAdD8bfA2ADEc74Cf9"

        const wBTCprice = "46100000000000000000000";

        const wBTCinitialMarginFee = "50000000000000000"
        const wBTCliquidationFee = "100000000000000000"
        const wBTCinitialMarginRequirement = "200000000000000000"
        const wBTCMaintenanceMarginRequirement = "100000000000000000"
        const wBTCoptimalBorrowProportion = "700000000000000000"
        const wBTCmaximumBorrowProportion = "1000000000000000000"
        const wBTC_interestRate = "5000000000000000"
        const wBTC_interestRateInfo = ["5000000000000000", "100000000000000000", "1000000000000000000"]

        const MATIC = "0x661a3a439B25B9aD39f15289D668e6607c0B336d"

        const MATICprice = "910000000000000000";

        const MATICinitialMarginFee = "50000000000000000"
        const MATICliquidationFee = "100000000000000000"
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

        */
        const ex = "0x87e02373945F4DBD9cb4f640CF59baaf86327A36"
        const DH = "0xfc3f0E8eaEB9Ba9C52E84fc777Dd41964eAC4252"
        const DV = "0xa9d870a4480F8E0093cfbc1632F1eee32Df89115"
        const oracle = "0xA0F9a39d656724a65561980c44e52bb80c232F79"
        const util = "0x3138C2F7723EA5a9748D59d6FADC5627Fe916749"
        const interest = "0xf1d2e67C64Cbb486BdC07955fCCFD1F635f9483C"
        const liq = "0x8dF103078B500A89E72f95a02a02030Cfe7Ca080"

        const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

        console.log("Removing pending with account:", deployer.address);

        const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

        const Utils = new hre.ethers.Contract(util, utilABI.abi, deployer);


        const pendingBalanceUSDT = await Utils.returnPending(deployer.address, USDT)

        console.log(pendingBalanceUSDT )
        const pendingBalanceREXE = await Utils.returnPending(deployer.address, USDT)
        console.log(pendingBalanceREXE )
        const removepending = await DataHub.removePendingBalances(deployer.address, USDT, pendingBalanceUSDT)

        removepending.wait()

        const removependingREX = await DataHub.removePendingBalances(deployer.address, REXE, pendingBalanceREXE)

        removependingREX.wait()


}main()