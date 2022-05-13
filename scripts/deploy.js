// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  const StableCashFlow = await hre.ethers.getContractFactory("StableCashFlow");
  const fDAIx = "0xBF6201a6c48B56d8577eDD079b84716BB4918E8A";
  const fUSDCx = "0x2dC36872a445adF0bFf63cc0eeee52A2b801625f";
  const host = "0xF2B4E81ba39F5215Db2e05B2F66f482BB8e87FD2";
  const cfa = "0xaD2F1f7cd663f6a15742675f975CcBD42bb23a88";
  const stableCashFlow = await StableCashFlow.deploy(host, cfa, fDAIx, fUSDCx);

  await stableCashFlow.deployed();

  console.log("StableCashFlow deployed to:", stableCashFlow.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
