const hre = require("hardhat");
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")
const LiquidatorAbi = require("../artifacts/contracts/liquidator.sol/Liquidator.json")
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")

async function main(){
        //const ex = "0x3BDa6E23ee7DEEe1fdf0E826D78F529C7304997C" original working 
       //  const ex ="0x34855845Dd334C6970e98227436be5F550e7e5a8" 2nd one not working with large charg mass interest in 
       //const ex ="0xF0fF0B479193Ef6329F4dAA77200dC89eAF309ab" 3rd still not working with charge mas intereat public in the interest charge fctiion
       // something is worng with charge mass interesst what is wrong is below 
       // whats wrong is Datahub.fetchTotalBorrowedAmount(token); function does not exist you must replace it 
       //Exchange deployed to 0xF5E276a29103Ab06Fb9e7E67AD6A6C807b7418b6 trade fees in  they work but not correct the math is wrong
     //  const ex = "0xF5E276a29103Ab06Fb9e7E67AD6A6C807b7418b6"
     /*
     const ex = "0x04CfbA4820f575159470dADbBe0C5e1E0Df8005C" // this has debit deposit interest
        const DH = "0xfc3f0E8eaEB9Ba9C52E84fc777Dd41964eAC4252"
        const DV = "0xa9d870a4480F8E0093cfbc1632F1eee32Df89115"
        const oracle = "0xA0F9a39d656724a65561980c44e52bb80c232F79"
        const util = "0x3138C2F7723EA5a9748D59d6FADC5627Fe916749"
        const interest = "0xf1d2e67C64Cbb486BdC07955fCCFD1F635f9483C"
        const liq = "0x8dF103078B500A89E72f95a02a02030Cfe7Ca080"
*/

//0xBb20dFac2c4cBdd0729787ac5869613554aE1361

//const ex = "0x4E1Dc2D90E81Ad889054Ef2668B5Ab5fDDdf23bf"
const ex = "0xBb20dFac2c4cBdd0729787ac5869613554aE1361"
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

}main()