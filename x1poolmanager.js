const { promisify } = require('util');
const { exec } = require('child_process');
const fs = require('fs');

const execAsync = promisify(exec);
const poolKeypairsPath = 'pool_keypairs.json';
const configPath = 'config.json';

async function main() {
  console.log("X1 Stake Pool Manager v0.0.3 - By BlackBeard\n");

  // Read config.json to get min reserve and delegate
  let minReserveBalance = null;
  let delegate = null;
  try {
    const configData = await fs.promises.readFile(configPath, 'utf8');
    const config = JSON.parse(configData);
    minReserveBalance = config.reserve; // optional
    delegate = config.delegate; // optional
  } catch (err) {
    // If config.json doesn't exist or can't be read, proceed with nulls
    minReserveBalance = null;
    delegate = null;
  }

  // Read pool_keypairs.json
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
  // Include min reserve balance if available
  const minReserveDisplay = minReserveBalance !== null ? `     Min Reserve Balance: ${minReserveBalance}` : '';

  console.log(`Pool: ${poolAddress}`);
  // Show reserve and min reserve on the same line if minReserveBalance is available
  if (minReserveBalance !== null) {
    console.log(`Reserve: ${reserveBalanceNumber} XNT  ${minReserveDisplay}`);
  } else {
    console.log(`Reserve: ${reserveBalanceNumber} XNT`);
  }
  // Show validators and Stake/Val on same line if delegate is available
  if (delegate !== null) {
    console.log(`Validators: ${validatorCount}            Stake/Val: ${delegate}`);
  } else {
    console.log(`Validators: ${validatorCount}`);
  }
}

main().catch((err) => {
  console.error('An unexpected error occurred:', err);
});
