const hre = require("hardhat");

async function main() {
  const MockERC20 = await hre.ethers.getContractFactory("MockERC20");
  const tA = await MockERC20.deploy("Token A", "TKA");
  const tB = await MockERC20.deploy("Token B", "TKB");

  const DEX = await hre.ethers.getContractFactory("DEX");
  const dex = await DEX.deploy(tA.address, tB.address);

  console.log("DEX deployed to:", dex.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});