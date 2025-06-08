const { promisify } = require('util');
const { exec } = require('child_process');
const fs = require('fs');

const execAsync = promisify(exec);
const poolKeypairsPath = 'pool_keypairs.json';

async function main() {
  console.log("X1 Stake Pool Manager - By BlackBeard\n");

  let poolData;
  try {
    const data = await fs.promises.readFile(poolKeypairsPath, 'utf8');
    poolData = JSON.parse(data);
  } catch (err) {
    // File doesn't exist or can't be read
    console.log('Connect a Pool to the manager');
    return;
  }

  const { stakePoolKeypair, reserveKeypair, splStakePoolCommand } = poolData;

  if (!stakePoolKeypair || !reserveKeypair || !splStakePoolCommand) {
    // Missing keypairs in JSON
    console.log('Connect a Pool to the manager');
    return;
  }

  // Step 1: Get pool address
  const poolAddressCmd = `solana address -k ${stakePoolKeypair}`;
  const { stdout: poolAddressStdout } = await execAsync(poolAddressCmd);
  const poolAddress = poolAddressStdout.trim();

  // Step 2: Get reserve balance
  const balanceCmd = `solana balance ${reserveKeypair}`;
  const { stdout: balanceStdout } = await execAsync(balanceCmd);
  const reserveBalanceStr = balanceStdout.trim();
  const reserveBalanceNumberMatch = reserveBalanceStr.match(/^[\d.,]+/);
  const reserveBalanceNumber = reserveBalanceNumberMatch ? reserveBalanceNumberMatch[0] : reserveBalanceStr;

  // Step 3: Get validator count
  const grepCmd = `${splStakePoolCommand} list-all | grep ${poolAddress}`;
  const { stdout: grepOutput } = await execAsync(grepCmd);
  const match = grepOutput.match(/Validators:\s*(\d+)/);
  const validatorCount = match ? match[1] : 'N/A';

  // Output the results
  console.log(`Pool: ${poolAddress}`);
  console.log(`Reserve: ${reserveBalanceNumber} XNT`);
  console.log(`Validators: ${validatorCount}`);
}

main().catch((err) => {
  console.error('An unexpected error occurred:', err);
});
