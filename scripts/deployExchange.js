
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners(0);

  console.log("Deploying contracts with the account:", deployer.address);

  const initialOwner = deployer.address // insert wallet address 
 
  // Deploy REXE library
  const Exchange = await hre.ethers.getContractFactory("EVO_EXCHANGE", {
    libraries: {
      EVO_LIBRARY: "0x57E52102561799B60Ebb5c8Cea8bef040C19cb5a",
    },
  });


  const Deploy_Exchange = await Exchange.deploy(initialOwner, initialOwner, initialOwner, initialOwner, initialOwner, initialOwner, initialOwner);

  console.log("Exchange deployed to", await Deploy_Exchange.getAddress());

}
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });