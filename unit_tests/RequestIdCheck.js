

const hre = require("hardhat");
const OracleABI  = require("../artifacts/contracts/Oracle.sol/Oracle.json")


async function main(){

    const oracle = "0xB2e7443350e7d2e7bF2DcBc911760009eC84132a"


    const USDT = "0xaBAD60e4e01547E2975a96426399a5a0578223Cb"


  
    const REXE = "0x1E67a46D59527B8a77D1eC7C6EEc0B06FcF31E28"

   

    const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

    console.log("Querying with account ", deployer.address);

   
    const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

    console.log(await Oracle.fulfilledData("0xC1A010002E22259A388950F9CEB76E71150D16B76E4CD0AB453E4A7DA018F6EF"));
    console.log(await Oracle.OrderDetails("0xC1A010002E22259A388950F9CEB76E71150D16B76E4CD0AB453E4A7DA018F6EF"));
    

}
main();