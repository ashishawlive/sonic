import { ethers, upgrades } from "hardhat";

async function main() {
  const ContractFactory = await ethers.getContractFactory("Sonic");
  const instance = await upgrades.deployProxy(ContractFactory, ["0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"]);

  await instance.deployed();

  console.log("Sonic deployed to:", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266");
  return true;
}


// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
