const https = require('https');
const fs = require('fs');
const { exec } = require('child_process');

// Helper function for retries
async function retryOperation(operation, retries = 10, delayMs = 3000) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      return await operation();
    } catch (err) {
      if (attempt === retries) {
        throw err;
      }
      await new Promise(res => setTimeout(res, delayMs));
    }
  }
}

// Define options for getSlot RPC
const options = {
  hostname: 'rpc.testnet.x1.xyz', // replace with your RPC URL
  port: 443,
  path: '/',
  method: 'POST',
  headers: { 'Content-Type': 'application/json' }
};

// Function to fetch current chain slot with retry
async function getChainSlot() {
  const data = JSON.stringify({ jsonrpc: "2.0", id: 1, method: "getSlot" });
  return retryOperation(() => new Promise((resolve, reject) => {
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
  }));
}

// Helper to run shell commands with retry
function runCommand(cmd) {
  return retryOperation(() => new Promise((resolve, reject) => {
    exec(cmd, (error, stdout, stderr) => {
      if (error) {
        reject(error);
      } else {
        resolve(stdout);
      }
    });
  }));
}

// Fetch second epoch credits
async function getSecondEpochCredits(voteAddress) {
  try {
    const output = await runCommand(`solana vote-account ${voteAddress}`);
    const lines = output.split('\n');
    const creditsLines = lines.filter(line => line.includes('credits/max credits'));
    if (creditsLines.length < 2) return '0';
    const secondLine = creditsLines[1];
    const match = secondLine.match(/credits\/max credits:\s*(\d+)\s*\/\s*\d+/);
    return match && match[1] ? match[1] : '0';
  } catch {
    return null; // indicate failure
  }
}

// Fetch total credits
async function getTotalCredits(voteAddress) {
  try {
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
  } catch {
    return null;
  }
}

// Fetch recent votes and compute average latency
async function getValidatorLatency(votePubkey) {
  try {
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
  } catch {
    return null;
  }
}

// Fetch validator skip rate via new method
async function getValidatorSkipRate(nodePubkey) {
  try {
    // 1. Get the current epoch
    const epochInfoOutput = await runCommand('solana epoch-info');
    const epochMatch = epochInfoOutput.match(/Epoch:\s*(\d+)/);
    if (!epochMatch || !epochMatch[1]) return 'N/A';
    const epoch = parseInt(epochMatch[1], 10);

    // 2. Run block-production for epoch-1
    const blockProdOutput = await runCommand(`solana block-production --epoch ${epoch - 1}`);

    // 3. Parse output to get skip rate for the nodePubkey
    const lines = blockProdOutput.split('\n');
    for (const line of lines) {
      if (line.includes(nodePubkey)) {
        // match line containing the skip rate
        const match = line.match(/\s*[\w\d]+.*\s*[\d]+\s*[\d]+\s*[\d]+\s*([\d.]+)%/);
        if (match && match[1]) {
          // ensure full number with 2 decimal places
          const skipRateStr = parseFloat(match[1]).toFixed(2) + '%';
          return skipRateStr;
        }
      }
    }
    // If not found, return 'N/A'
    return 'N/A';
  } catch {
    return 'N/A';
  }
}

// Fallback: get skip rate from 'solana validators' command
//function getValidatorSkipRateFallback(votePubkey) {
//  return runCommand(`solana validators | grep ${votePubkey} | awk '{print $11}'`)
//    .then(output => {
//      const outTrim = output.trim();
//      if (
//        outTrim === '' ||
//        outTrim.includes('N/A') ||
//        outTrim.includes('-')
//      ) {
//        return 'N/A';
//      } else {
//        return outTrim;
//      }
//    })
//    .catch(() => 'N/A');
//}

// Fetch average credits with retry
async function getAverageCredits(votePubkey) {
  try {
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
    if (creditsValues.length === 0) return null;
    const sum = creditsValues.reduce((a, b) => a + b, 0);
    return (sum / creditsValues.length).toFixed(2);
  } catch {
    return null;
  }
}

// Fetch vote accounts data with retry
function fetchVoteAccounts() {
  return retryOperation(() => new Promise((resolve, reject) => {
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
  }));
}

// Read existing CSV or initialize headers
function readExistingCSV() {
  if (fs.existsSync('chain_validators.csv')) {
    const content = fs.readFileSync('chain_validators.csv', 'utf-8');
    const lines = content.split('\n');
    if (lines.length > 0 && lines[0].startsWith('Vote Pubkey')) {
      return lines;
    }
  }
  const header = 'Vote Pubkey,Node Pubkey,Activated Stake,Commission,Last Vote,Second Epoch Credits,Total Credits,Average Credits,Status,Skip Rate,Latency';
  return [header];
}

// Save CSV lines
function saveCSV(lines) {
  fs.writeFileSync('chain_validators.csv', lines.join('\n'));
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

    // 4. Read existing CSV
    const existingLines = readExistingCSV();
    const header = existingLines[0];
    const existingData = {};
    for (let i = 1; i < existingLines.length; i++) {
      const row = existingLines[i].split(',');
      const votePubkey = row[0];
      existingData[votePubkey] = row;
    }

    // 5. Update config.json
    const config = {};
    if (fs.existsSync('config.json')) {
      try {
        Object.assign(config, JSON.parse(fs.readFileSync('config.json')));
      } catch {}
    }
    config.chainSlot = chainSlot;
    config.totalValidators = totalValidators;
    config.currentValidators = currentCount;
    config.delinquentValidators = delinquentCount;
    fs.writeFileSync('config.json', JSON.stringify(config, null, 2));
    console.log('Updated config.json with chain slot and validator counts');

    const allAccounts = [
      ...(result.current || []).map(acc => ({ ...acc, status: 'current' })),
      ...(result.delinquent || []).map(acc => ({ ...acc, status: 'delinquent' }))
    ];

    const newLines = [header];

    // 6. Process all vote accounts
    await Promise.all(allAccounts.map(async (acc) => {
      const { votePubkey, nodePubkey, activatedStake, lastVote } = acc;
      const { commission = 'N/A' } = acc;

      // Fetch data, fallback to existing if fail
      const [
        secondEpochCredits,
        totalCredits,
        latency,
        averageCredits,
        skipRate
      ] = await Promise.all([
        getSecondEpochCredits(votePubkey),
        getTotalCredits(votePubkey),
        getValidatorLatency(votePubkey),
        getAverageCredits(votePubkey),
        // Use new method for skip rate:
        getValidatorSkipRate(nodePubkey).catch(() => 'N/A')
      ]);

      // Retrieve existing data if fetch failed
      const existing = existingData[votePubkey] || [];

      const getField = (fieldName, newValue) => {
        if (newValue === null || newValue === undefined || newValue === 'N/A') {
          return existing.length ? existing[fieldNameToIndex(fieldName)] : 'N/A';
        }
        return newValue;
      };

      // Helper to get index of a field in CSV
      function fieldNameToIndex(fieldName) {
        const fields = header.split(',');
        return fields.indexOf(fieldName);
      }

      const row = [
        votePubkey,
        nodePubkey,
        activatedStake,
        commission,
        lastVote,
        getField('Second Epoch Credits', secondEpochCredits),
        getField('Total Credits', totalCredits),
        getField('Average Credits', averageCredits),
        acc.status,
        getField('Skip Rate', skipRate),
        getField('Latency', latency)
      ];

      newLines.push(row.join(','));
    }));

    // 7. Save updated CSV
    saveCSV(newLines);
    console.log('Data saved to chain_validators.csv');

  } catch (err) {
    console.error('Error:', err);
  }
}

main();
