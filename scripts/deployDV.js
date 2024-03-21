// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners(0);

  console.log("Deploying contracts with the account:", deployer.address);

  const DH = "0xcb333C6D38Ee39D0C57eFC2e0c1D13663Eb89D4B"
  const ex = "0x5D441FD5Eb1Be84b28450b658d429f3faE3F95e4"
  const int = "0x8C4D71E2979DaF7655DC7627E82f73a65ACD4F12"
  const initialOwner = deployer.address // insert wallet address 

  const depositVault = await hre.ethers.getContractFactory("DepositVault", {
    libraries: {
      REX_LIBRARY: "0xa8166FD68B4698f431a55a810e74F8326d43cd37",
    },
  });
  const Deploy_depositVault = await depositVault.deploy(initialOwner, DH, ex, int);

  await Deploy_depositVault.waitForDeployment();

  console.log("Deposit Vault deployed to", await Deploy_depositVault.getAddress());


}
//npx hardhat run scripts/deploy.js --network mumbai
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
