const https = require('https');
const fs = require('fs');
const { exec } = require('child_process');

// Define options for getSlot RPC
const options = {
  hostname: 'rpc.testnet.x1.xyz', // replace with your RPC URL
  port: 443,
  path: '/',
  method: 'POST',
  headers: { 'Content-Type': 'application/json' }
};

// Function to fetch current chain slot
function getChainSlot() {
  const data = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getSlot" });
  return new Promise((resolve, reject) => {
    const req = https.request({ ...options, headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) } }, (res) => {
      let resData = '';
      res.on('data', chunk => resData += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(resData);
          resolve(json.result);
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', (e) => reject(e));
    req.write(data);
    req.end();
  });
}

// Helper to run shell commands
function runCommand(cmd) {
  return new Promise((resolve) => {
    exec(cmd, (error, stdout, stderr) => {
      if (error) {
        resolve('');
      } else {
        resolve(stdout);
      }
    });
  });
}

// Fetch second epoch credits
async function getSecondEpochCredits(voteAddress) {
  const output = await runCommand(`solana vote-account ${voteAddress}`);
  const lines = output.split('\n');
  const creditsLines = lines.filter(line => line.includes('credits/max credits'));
  if (creditsLines.length < 2) return '0';
  const secondLine = creditsLines[1];
  const match = secondLine.match(/credits\/max credits:\s*(\d+)\s*\/\s*\d+/);
  return match && match[1] ? match[1] : '0';
}

// Fetch total credits
async function getTotalCredits(voteAddress) {
  const output = await runCommand(`solana vote-account ${voteAddress}`);
  let totalCredits = 0;
  const lines = output.split('\n');
  for (const line of lines) {
    if (line.startsWith('Credits:')) {
      const parts = line.trim().split(/\s+/);
      const credits = parseInt(parts[1], 10);
      if (!isNaN(credits)) totalCredits += credits;
    }
  }
  return totalCredits.toString();
}

// Fetch recent votes and compute average latency
async function getValidatorLatency(votePubkey) {
  const output = await runCommand(`solana vote-account ${votePubkey}`);
  const latencies = [];
  const lines = output.split('\n');
  let inRecentVotes = false;
  for (let line of lines) {
    if (line.includes('Recent Votes (using 31/31 entries):')) {
      inRecentVotes = true;
      continue;
    }
    if (inRecentVotes) {
      if (line.trim() === '') break;
      const match = line.match(/\(latency (\d+)\)/);
      if (match && match[1]) latencies.push(parseInt(match[1], 10));
    }
  }
  if (latencies.length === 0) return 'N/A';
  const count = latencies.length;
  const startIdx = Math.max(0, count - 31);
  const sum = latencies.slice(startIdx).reduce((a, b) => a + b, 0);
  return (sum / (count - startIdx)).toFixed(2);
}

// Fetch validator skip rate
function getValidatorSkipRate(votePubkey) {
  return new Promise((resolve) => {
    runCommand(`solana validators | grep ${votePubkey} | awk '{print $11}'`)
      .then(output => {
        const outTrim = output.trim();
        if (
          outTrim === '' ||
          outTrim.includes('N/A') ||
          outTrim.includes('-')
        ) {
          resolve('N/A');
        } else {
          resolve(outTrim);
        }
      });
  });
}

// Fetch vote account info and calculate average credits
async function getAverageCredits(votePubkey) {
  const output = await runCommand(`solana vote-account ${votePubkey}`);
  const creditsValues = [];
  let skipFirst = true;
  const lines = output.split('\n');
  for (const line of lines) {
    if (line.includes('credits/max credits:')) {
      if (skipFirst) {
        skipFirst = false; // skip first occurrence
        continue;
      }
      const match = line.match(/credits\/max credits:\s*(\d+)/);
      if (match && match[1]) {
        creditsValues.push(parseInt(match[1], 10));
      }
    }
  }
  if (creditsValues.length === 0) return 'N/A';
  const sum = creditsValues.reduce((a, b) => a + b, 0);
  return (sum / creditsValues.length).toFixed(2);
}

// Fetch vote accounts data
function fetchVoteAccounts() {
  return new Promise((resolve, reject) => {
    const req = https.request({ ...options, headers: { 'Content-Type': 'application/json' } }, (res) => {
      let responseData = '';
      res.on('data', (chunk) => { responseData += chunk; });
      res.on('end', () => {
        try {
          const json = JSON.parse(responseData);
          resolve(json.result);
        } catch (err) {
          reject(new Error('Failed to parse JSON response.'));
        }
      });
    });
    req.on('error', (e) => reject(e));
    req.write(JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getVoteAccounts" }));
    req.end();
  });
}

// Read existing config.json or initialize empty object
function readConfig() {
  if (fs.existsSync('config.json')) {
    const raw = fs.readFileSync('config.json');
    try {
      return JSON.parse(raw);
    } catch (e) {
      return {};
    }
  }
  return {};
}

// Save updated config.json
function saveConfig(obj) {
  fs.writeFileSync('config.json', JSON.stringify(obj, null, 2));
}

// Main execution
async function main() {
  try {
    // 1. Get chain slot
    const chainSlot = await getChainSlot();

    // 2. Fetch vote accounts
    const result = await fetchVoteAccounts();

    // 3. Count current/delinquent
    const currentCount = result.current ? result.current.length : 0;
    const delinquentCount = result.delinquent ? result.delinquent.length : 0;
    const totalValidators = currentCount + delinquentCount;

    // 4. Read existing config, update entries
    const config = readConfig();

    // Update relevant entries
    config.chainSlot = chainSlot;
    config.totalValidators = totalValidators;
    config.currentValidators = currentCount;
    config.delinquentValidators = delinquentCount;

    // Save back the config
    saveConfig(config);
    console.log('Updated config.json with chain slot and validator counts');

    const allAccounts = [
      ...(result.current || []).map(acc => ({ ...acc, status: 'current' })),
      ...(result.delinquent || []).map(acc => ({ ...acc, status: 'delinquent' }))
    ];

    const rows = [];

    // 5. Process all vote accounts
    await Promise.all(allAccounts.map(async (acc) => {
      const { votePubkey, nodePubkey, activatedStake, lastVote } = acc;
      const { commission = 'N/A' } = acc;

      const [secondEpochCredits, totalCredits, latency] = await Promise.all([
        getSecondEpochCredits(votePubkey),
        getTotalCredits(votePubkey),
        getValidatorLatency(votePubkey)
      ]);

      const averageCredits = await getAverageCredits(votePubkey);
      const skipRate = await getValidatorSkipRate(votePubkey);

      rows.push({
        votePubkey,
        nodePubkey,
        activatedStake,
        commission,
        lastVote,
        secondEpochCredits,
        totalCredits,
        status: acc.status,
        skipRate,
        latency,
        averageCredits
      });
    }));

    // 6. Write CSV
    const header = 'Vote Pubkey,Node Pubkey,Activated Stake,Commission,Last Vote,Second Epoch Credits,Total Credits,Average Credits,Status,Skip Rate,Latency\n';
    const csvContent = rows.map(r =>
      `${r.votePubkey},${r.nodePubkey},${r.activatedStake},${r.commission},${r.lastVote},${r.secondEpochCredits},${r.totalCredits},${r.averageCredits},${r.status},${r.skipRate},${r.latency}`
    ).join('\n');

    fs.writeFileSync('chain_validators.csv', header + csvContent);
    console.log('Data saved to chain_validators.csv');

  } catch (err) {
    console.error('Error:', err);
  }
}

main();
