import { ethers } from "hardhat";

async function main() {

  const airnode = "0x2ab9f26E18B64848cd349582ca3B55c2d06f507d" // Airnode sepolia
  // The new way of deploying contracts    Name of Contract, Constructor Arguments, Overrides
  const tokenEx = await ethers.deployContract("QrngExample", [airnode], {});

  await tokenEx.waitForDeployment();

  console.log(
    `TokenEx contract address: ${tokenEx.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
