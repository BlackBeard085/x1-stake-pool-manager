const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');

const keypairsPath = 'pool_keypairs.json';
const poolValidatorsCsvPath = 'pool_validators.csv';
const chainValidatorsCsvPath = 'chain_validators.csv';
const configPath = 'config.json';

// Helper to read CSV into a map: pubkey -> data object
function readCsvAsMap(csvFilePath) {
  return new Promise((resolve, reject) => {
    if (!fs.existsSync(csvFilePath)) {
      resolve(new Map());
      return;
    }
    fs.readFile(csvFilePath, 'utf8', (err, data) => {
      if (err) {
        reject(err);
        return;
      }
      const lines = data.trim().split('\n');
      if (lines.length === 0) resolve(new Map());

      const headers = lines[0].split(',');
      const pubkeyIdx = headers.indexOf('Vote Pubkey');

      const map = new Map();
      for (let i = 1; i < lines.length; i++) {
        const cols = lines[i].split(',');
        const pubkey = cols[pubkeyIdx];
        if (pubkey) {
          const obj = {};
          headers.forEach((header, index) => {
            obj[header] = cols[index] || '';
          });
          map.set(pubkey, obj);
        }
      }
      resolve(map);
    });
  });
}

// Helper to write a map back to CSV
function writeMapToCsv(map, csvFilePath) {
  return new Promise((resolve, reject) => {
    if (map.size === 0) {
      // Write only headers if empty
      fs.writeFile(csvFilePath, 'Vote Pubkey,Node Pubkey,Activated Stake,Commission,Last Vote,Second Epoch Credits,Total Credits,Average Credits,Status,Skip Rate,Latency\n', 'utf8', err => {
        if (err) reject(err);
        else resolve();
      });
      return;
    }

    const headers = Object.keys([...map.values()][0]);
    const lines = [headers.join(',')];

    for (const obj of map.values()) {
      const line = headers.map(h => obj[h] || '').join(',');
      lines.push(line);
    }

    fs.writeFile(csvFilePath, lines.join('\n'), 'utf8', err => {
      if (err) reject(err);
      else resolve();
    });
  });
}

// Helper to find chain validator data for a pubkey
async function getChainValidatorData(pubkey) {
  const chainMap = await readCsvAsMap(chainValidatorsCsvPath);
  if (chainMap.has(pubkey)) {
    return chainMap.get(pubkey);
  }
  return null;
}

// Append a newline if the file doesn't end with one
function ensureTrailingNewline(filePath) {
  return new Promise((resolve, reject) => {
    fs.readFile(filePath, 'utf8', (err, data) => {
      if (err) {
        // If file doesn't exist, just resolve
        if (err.code === 'ENOENT') return resolve();
        return reject(err);
      }
      if (data.endsWith('\n')) {
        resolve();
      } else {
        fs.appendFile(filePath, '\n', err => {
          if (err) reject(err);
          else resolve();
        });
      }
    });
  });
}

// Helper to read config.json
function readConfig() {
  return new Promise((resolve, reject) => {
    fs.readFile(configPath, 'utf8', (err, data) => {
      if (err) {
        if (err.code === 'ENOENT') {
          resolve({}); // default empty config
        } else {
          reject(err);
        }
        return;
      }
      try {
        resolve(JSON.parse(data));
      } catch (parseErr) {
        reject(parseErr);
      }
    });
  });
}

// Helper to write config.json
function writeConfig(config) {
  return new Promise((resolve, reject) => {
    fs.writeFile(configPath, JSON.stringify(config, null, 2), 'utf8', err => {
      if (err) reject(err);
      else resolve();
    });
  });
}

// Main process
(async () => {
  try {
    // Read existing CSV into map
    const existingMap = await readCsvAsMap(poolValidatorsCsvPath);
    const existingPubkeys = new Set(existingMap.keys());

    // Read chain_validators.csv
    const chainMap = await readCsvAsMap(chainValidatorsCsvPath);

    // Read config.json
    const config = await readConfig();

    // Read keypairs
    const data = fs.readFileSync(keypairsPath, 'utf8');
    const keypairs = JSON.parse(data);
    const { splStakePoolCommand, stakePoolKeypair } = keypairs;

    // Get pool address
    exec(`solana address -k ${stakePoolKeypair}`, (err, stdout, stderr) => {
      if (err) {
        console.error('Error executing solana address:', err);
        return;
      }

      const poolAddress = stdout.trim();
      console.log(`Pool Address: ${poolAddress}`);

      // Run the stake pool command
      const command = `${splStakePoolCommand} list ${poolAddress} -v`;
      exec(command, async (err, stdout, stderr) => {
        if (err) {
          console.error(`Error executing command "${command}":`, err);
          return;
        }

        const lines = stdout.split('\n');

        const voteActiveBalances = {}; // { votePubkey: activeBalance }
        const currentVotePubkeys = new Set();

        // Parse vote accounts and active balances
        for (let i = 0; i < lines.length; i++) {
          const line = lines[i];
          const voteMatch = line.match(/Vote Account:\s*(\S+)/);
          if (voteMatch) {
            const votePubkey = voteMatch[1];
            // Find Active Balance
            for (let j = i; j < lines.length; j++) {
              const activeLine = lines[j];
              const activeMatch = activeLine.match(/Active Balance:\s*◎([\d.]+)/);
              if (activeMatch) {
                const activeBalanceStr = activeMatch[1];
                voteActiveBalances[votePubkey] = parseFloat(activeBalanceStr);
                break;
              }
            }
            currentVotePubkeys.add(votePubkey);
          }
        }

        // Determine majority active balance
        const balanceCounts = {};
        for (const pubkey in voteActiveBalances) {
          const balance = voteActiveBalances[pubkey];
          balanceCounts[balance] = (balanceCounts[balance] || 0) + 1;
        }

        let majorityBalance = null;
        let maxCount = 0;
        for (const balance in balanceCounts) {
          if (balanceCounts[balance] > maxCount) {
            maxCount = balanceCounts[balance];
            majorityBalance = balance;
          }
        }
        if (majorityBalance !== null) {
          console.log(`Majority Active Balance: ◎${majorityBalance}`);
        } else {
          console.log('No active balances found.');
        }

        // Handle removal of pubkeys not in current output
        const pubkeysInOutput = new Set(Object.keys(voteActiveBalances));
        const pubkeysToRemove = [...existingMap.keys()].filter(pk => !pubkeysInOutput.has(pk));

        // Remove pubkeys not in output
        for (const pk of pubkeysToRemove) {
          existingMap.delete(pk);
        }

        // Handle adding new pubkeys
        for (const pk of currentVotePubkeys) {
          if (!existingMap.has(pk)) {
            // Create new entry, fill with chain data if available
            const chainData = await getChainValidatorData(pk);
            const newEntry = {};

            // Fill with chain data if available
            if (chainData) {
              Object.keys(chainData).forEach(key => {
                newEntry[key] = chainData[key];
              });
            }

            // Ensure all fields present
            const headers = [...existingMap.values()][0]
              ? Object.keys([...existingMap.values()][0])
              : [];

            headers.forEach(header => {
              if (!(header in newEntry)) {
                newEntry[header] = '';
              }
            });

            // Set the pubkey
            newEntry['Vote Pubkey'] = pk;

            // Add the new entry
            existingMap.set(pk, newEntry);
          }
        }

        // Save the updated CSV
        await writeMapToCsv(existingMap, poolValidatorsCsvPath);
        console.log('Updated pool_validators.csv: removed missing pubkeys and added new ones.');

        // Append a newline if not already ending with one
        await ensureTrailingNewline(poolValidatorsCsvPath);

        // Recalculate majority active balance after update
        const updatedVoteBalances = {};
        for (const pk of existingMap.keys()) {
          if (voteActiveBalances[pk] !== undefined) {
            updatedVoteBalances[pk] = voteActiveBalances[pk];
          }
        }
        const balanceCountMap = {};
        for (const pubk in updatedVoteBalances) {
          const bal = updatedVoteBalances[pubk];
          balanceCountMap[bal] = (balanceCountMap[bal] || 0) + 1;
        }
        let majorityBalanceFinal = null;
        let maxCountFinal = 0;
        for (const balance in balanceCountMap) {
          if (balanceCountMap[balance] > maxCountFinal) {
            maxCountFinal = balanceCountMap[balance];
            majorityBalanceFinal = balance;
          }
        }
        if (majorityBalanceFinal !== null) {
          console.log(`Majority Active Balance: ◎${majorityBalanceFinal}`);
        } else {
          console.log('No active balances found in final calculation.');
        }

        // Check config.delegate and update if 0
        if (config.hasOwnProperty('delegate') && config.delegate === 0) {
          if (majorityBalanceFinal !== null) {
            const newDelegateValue = parseFloat(majorityBalanceFinal).toFixed(2);
            config.delegate = parseFloat(newDelegateValue);
            await writeConfig(config);
            console.log(`Updated config.delegate to ${newDelegateValue} (2 decimals).`);
          }
        }
      });
    });
  } catch (err) {
    console.error('Error:', err);
  }
})();
