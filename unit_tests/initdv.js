const hre = require("hardhat");
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/REX_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");

async function main() {


  const ex = "0x5D441FD5Eb1Be84b28450b658d429f3faE3F95e4"
  const DH = "0xcb333C6D38Ee39D0C57eFC2e0c1D13663Eb89D4B"
  // const DV = "0x8D972bba5fF715714c770EA6b8f4Bd3A39298B2D"
  const DV = "0xDC8F6B8704d8f90f61bFc9770c7bDB92809cF8e5"
  const oracle = "0xB2e7443350e7d2e7bF2DcBc911760009eC84132a"
  const util = "0x9A28852a3E1Bb56Da4a983B89C44383c6F5cD641"
  const int = "0x8C4D71E2979DaF7655DC7627E82f73a65ACD4F12"

  const [deployer] = await hre.ethers.getSigners(0);

  console.log("init with the account:", deployer.address);

  const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

  const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

  const utils = new hre.ethers.Contract(util, utilABI.abi, deployer);

  const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);

  ///////////////////////////////////
  const setup = await DataHub.AlterAdminRoles(DV, ex, oracle, int);

  setup.wait();
  ///////////////////////////////////

  const SETUP = await utils.alterAdminRoles(DH, DV, oracle);

  SETUP.wait()
  ///////////////////////////////////   
  const setupORacle = await Oracle.AlterAdminRoles(DV, ex, DH);

  setupORacle.wait()

  ///////////////////////////////////   


  const SETUPEX = await Exchange.alterAdminRoles(DH, DV, oracle, util, int);

  SETUPEX.wait()

} main();