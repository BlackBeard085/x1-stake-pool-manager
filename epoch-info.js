const { exec } = require('child_process');
const util = require('util');
const fs = require('fs');
const execPromise = util.promisify(exec);
const readFile = util.promisify(fs.readFile);

async function main() {
  try {
    // 1. Get RPC URL
    const { stdout: configStdout } = await execPromise('solana config get');
    const rpcUrlMatch = configStdout.match(/RPC URL:\s*(https?:\/\/[^\s]+)/);
    if (!rpcUrlMatch) {
      console.error('Could not find RPC URL in solana config.');
      return;
    }
    const rpcUrl = rpcUrlMatch[1];

    // 2. Fetch validator info
    const validatorsResponse = await fetchValidators(rpcUrl);
    if (!validatorsResponse) return;

    // 3. Parse validator data
    const { total, active, delinquent } = parseValidators(validatorsResponse);

    // 4. Read CSV files for additional info
    const shortlistCount = await countCsvEntries('staking_shortlist.csv');
    const prePoolCount = await countCsvEntries('pool_validators.csv');

    // 5. Read add_to_pool.txt for 'Awaiting stake' count
    const awaitingStakeCount = await countTextEntries('add_to_pool.txt');

    // 6. Get epoch info
    const epochInfo = await getEpochInfo();

    // 7. Display info
    console.log(`\nRPC URL: ${rpcUrl}`);
    if (epochInfo) {
      console.log(`Current Epoch: ${epochInfo.epoch} - ${epochInfo.remainingTime} remaining\n`);
    } else {
      console.log('Epoch info not available.\n');
    }

    // Prepare the table
    const columnWidths = {
      label: 20,
      total: 10,
      active: 10,
      delinquent: 12
    };

    const header = pad(' ', columnWidths.label) +
      '|' + pad('Total', columnWidths.total) +
      '|' + pad('Active', columnWidths.active) +
      '|' + pad('Delinquent', columnWidths.delinquent);
    const separator = '-'.repeat(header.length);

    // Print header and separator (no top separator line)
    console.log(header);
    console.log(separator);

    // Validators row
    const validatorRow = pad('Validators', columnWidths.label) +
      '|' + pad(String(total), columnWidths.total) +
      '|' + pad(String(active), columnWidths.active) +
      '|' + pad(String(delinquent), columnWidths.delinquent);
    console.log(validatorRow);

    // Shortlisted row
    const shortlistedRow = pad('Shortlisted', columnWidths.label) +
      '|' + pad(String(shortlistCount), columnWidths.total) +
      '|' + pad('', columnWidths.active) +
      '|' + pad('', columnWidths.delinquent);
    console.log(shortlistedRow);

    // Pre-Pool Validators row
    const prePoolRow = pad('Pre-Pool Validators', columnWidths.label) +
      '|' + pad(String(prePoolCount), columnWidths.total) +
      '|' + pad('', columnWidths.active) +
      '|' + pad('', columnWidths.delinquent);
    console.log(prePoolRow);

    // Awaiting Stake row
    const awaitingStakeRow = pad('Awaiting Stake', columnWidths.label) +
      '|' + pad(String(awaitingStakeCount), columnWidths.total) +
      '|' + pad('', columnWidths.active) +
      '|' + pad('', columnWidths.delinquent);
    console.log(awaitingStakeRow);

    // Bottom separator
    console.log(separator);

  } catch (err) {
    console.error('Error:', err);
  }
}

// Helper functions
function pad(str, width) {
  str = str || '';
  if (str.length >= width) return str.slice(0, width);
  return str + ' '.repeat(width - str.length);
}

async function countCsvEntries(filename) {
  try {
    const data = await readFile(filename, 'utf8');
    const lines = data.split('\n')
      .filter(line => line.trim() !== '' && !line.trim().startsWith('#') && !line.trim().toLowerCase().startsWith('header'));
    // Remove header line if present
    if (lines.length > 0 && lines[0].toLowerCase().includes('header')) {
      lines.shift();
    }
    // Remove the first data line if present
    if (lines.length > 0) {
      lines.shift(); // remove the first line after header
    }
    return lines.length;
  } catch (err) {
    // If file doesn't exist or error, treat as zero
    return 0;
  }
}

async function countTextEntries(filename) {
  try {
    const data = await readFile(filename, 'utf8');
    const lines = data.split('\n').filter(line => line.trim() !== '');
    return lines.length;
  } catch (err) {
    // If file doesn't exist or error, treat as zero
    return 0;
  }
}

async function fetchValidators(rpcUrl) {
  const payload = {
    jsonrpc: "2.0",
    id: 1,
    method: "getVoteAccounts"
  };
  try {
    const response = await fetch(rpcUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });
    const data = await response.json();
    if (data.error) {
      console.error('Error fetching validators:', data.error);
      return null;
    }
    return data.result;
  } catch (e) {
    console.error('Fetch error:', e);
    return null;
  }
}

function parseValidators(data) {
  const total = data.current.length + data.delinquent.length;
  const active = data.current.length;
  const delinquent = data.delinquent.length;
  return { total, active, delinquent };
}

async function getEpochInfo() {
  const { stdout } = await execPromise('solana epoch-info');
  const lines = stdout.split('\n');
  let epoch = null;
  let remainingTime = null;
  lines.forEach(line => {
    line = line.trim();
    if (line.startsWith('Epoch:')) {
      const match = line.match(/^Epoch:\s*(\d+)/);
      if (match) epoch = match[1];
    }
    if (line.startsWith('Epoch Completed Time:')) {
      const match = line.match(/\(([^)]+) remaining\)/);
      if (match) remainingTime = match[1];
    }
  });
  if (epoch && remainingTime) {
    return { epoch, remainingTime };
  }
  return null;
}

// Polyfill fetch
const https = require('https');
function fetch(url, options) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ json: () => JSON.parse(data) });
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    if (options.body) req.write(options.body);
    req.end();
  });
}

main();
