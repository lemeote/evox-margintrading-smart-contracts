const hre = require("hardhat");
const OracleABI = require("../artifacts/contracts/Oracle.sol/Oracle.json")
const ExecutorAbi = require("../artifacts/contracts/executor.sol/EVO_EXCHANGE.json")
const utilABI = require("../artifacts/contracts/utils.sol/Utility.json")
const DataHubAbi = require("../artifacts/contracts/datahub.sol/DataHub.json");
const depositABI = require("../artifacts/contracts/depositvault.sol/DepositVault.json")
async function main() {


  const ex = "0x82C19528944441bF4703C0f4bb4356521eC526ff"
  const DH = "0xb6f53a0D9932281e38056961A7afAecD6846418D"
  //const DV = "0xDC8F6B8704d8f90f61bFc9770c7bDB92809cF8e5"
  const DV ="0x1407A3e2Cbd3dA47E57f9260580Cf75DEE0A53C0"
  const oracle = "0x2d69e64bC23F8af2172F1c434A15B20a6c31e55E"
  const util = "0x156d790B12864E071A0b0eE8202C64079D346687"
  const int = "0xaF8749DA37232f2bbf3375642079841DCeEE0a4A"

  const [deployer] = await hre.ethers.getSigners(0);

  console.log("init with the account:", deployer.address);

  const DataHub = new hre.ethers.Contract(DH, DataHubAbi.abi, deployer);

  const DepositVault = new hre.ethers.Contract(DV, depositABI.abi, deployer);

  const Oracle = new hre.ethers.Contract(oracle, OracleABI.abi, deployer);

  const utils = new hre.ethers.Contract(util, utilABI.abi, deployer);

  const Exchange = new hre.ethers.Contract(ex, ExecutorAbi.abi, deployer);


  const setupDV = await DepositVault.alterdataHub(DH);

  setupDV.wait()

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