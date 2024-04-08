const hre = require("hardhat");
const InterestAbi = require("../artifacts/contracts/interestData.sol/interestData.json")

async function main() {

    const interest = "0x85c8b7e19045a528c89831bD93a47375931738f2"

    const USDT = "0xaBAD60e4e01547E2975a96426399a5a0578223Cb"

    const REXE = "0x1E67a46D59527B8a77D1eC7C6EEc0B06FcF31E28"

    const deployer = await hre.ethers.provider.getSigner(0); // change 0 / 1 for different wallets 

    console.log("Charging interest with the account:", deployer.address);

    const _Interest = new hre.ethers.Contract(interest, InterestAbi.abi, deployer);

    const interestREXE = await _Interest.chargeMassinterest(REXE)
    interestREXE.wait()
    console.log("Interest REXE  has been charged")
    const interestUSDT = await _Interest.chargeMassinterest(USDT)
    interestUSDT.wait();
    console.log("Interest USDT  has been charged")

    console.log("Interest has been charged")

} main()