
const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners(0);

  console.log("Deploying contracts with the account:", deployer.address);

  const DH = "0xb6f53a0D9932281e38056961A7afAecD6846418D"
  const ex = "0x82C19528944441bF4703C0f4bb4356521eC526ff"
  const dv = "0x1407A3e2Cbd3dA47E57f9260580Cf75DEE0A53C0"
  const initialOwner = deployer.address // insert wallet address 

  const Interest = await hre.ethers.getContractFactory("interestData", {
    libraries: {
      REX_LIBRARY: "0x383B5bD0FCc3df5c3965211aD811e2Af6Fd2Fd8E",
    },
  });
  let overrides = {
    gasLimit: 7500000
};
  const Deploy_depositVault = await Interest.deploy(initialOwner, DH, ex, dv,overrides);

  await Deploy_depositVault.waitForDeployment();

  console.log("Interest deployed to", await Deploy_depositVault.getAddress());


}
//npx hardhat run scripts/deploy.js --network mumbai
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
