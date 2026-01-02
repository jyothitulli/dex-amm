import pkg from "hardhat";
const { ethers } = pkg;

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with:", deployer.address);

  const Token = await ethers.getContractFactory("MockERC20");
  const tA = await Token.deploy("Token A", "TKA");
  const tB = await Token.deploy("Token B", "TKB");

  // For Hardhat v2.19+, use .waitForDeployment() instead of .deployed()
  await tA.waitForDeployment();
  await tB.waitForDeployment();

  const DEX = await ethers.getContractFactory("DEX");
  const dex = await DEX.deploy(await tA.getAddress(), await tB.getAddress());
  await dex.waitForDeployment();

  console.log("DEX Address:", await dex.getAddress());
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});