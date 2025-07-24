// pool_validators.js
const fs = require('fs');
const path = require('path');
const csvParser = require('csv-parser');
const { createObjectCsvWriter } = require('csv-writer');

const SHORTLIST_FILE = 'staking_shortlist.csv';
const POOL_FILE = 'pool_validators.csv';
const ADD_TO_POOL_FILE = 'add_to_pool.txt';

// Define the CSV headers
const headers = [
  { id: 'Vote Pubkey', title: 'Vote Pubkey' },
  { id: 'Node Pubkey', title: 'Node Pubkey' },
  { id: 'Activated Stake', title: 'Activated Stake' },
  { id: 'Commission', title: 'Commission' },
  { id: 'Last Vote', title: 'Last Vote' },
  { id: 'Second Epoch Credits', title: 'Second Epoch Credits' },
  { id: 'Total Credits', title: 'Total Credits' },
  { id: 'Average Credits', title: 'Average Credits' },
  { id: 'Status', title: 'Status' },
  { id: 'Skip Rate', title: 'Skip Rate' },
  { id: 'Latency', title: 'Latency' },
];

// Function to ensure pool_validators.csv exists and has headers
async function ensurePoolFile() {
  if (fs.existsSync(POOL_FILE)) {
    // Check if file is empty
    const stats = fs.statSync(POOL_FILE);
    if (stats.size === 0) {
      // File exists but is empty, write headers
      const csvWriter = createObjectCsvWriter({
        path: POOL_FILE,
        header: headers,
      });
      await csvWriter.writeRecords([]); // write headers
    }
    // Else, assume headers present
  } else {
    // File doesn't exist, create with headers
    const csvWriter = createObjectCsvWriter({
      path: POOL_FILE,
      header: headers,
    });
    await csvWriter.writeRecords([]); // create file with headers
  }
}

// Function to read CSV into a Map for quick lookup
function readCsvToMap(filePath) {
  return new Promise((resolve, reject) => {
    const map = new Map();
    if (!fs.existsSync(filePath)) {
      resolve(map);
      return;
    }
    fs.createReadStream(filePath)
      .pipe(csvParser())
      .on('data', (row) => {
        const votePubkey = row['Vote Pubkey'];
        if (votePubkey) {
          map.set(votePubkey, row);
        }
      })
      .on('end', () => {
        resolve(map);
      })
      .on('error', (err) => {
        reject(err);
      });
  });
}

// Function to read the shortlist CSV
function readShortlist() {
  return new Promise((resolve, reject) => {
    const entries = [];
    if (!fs.existsSync(SHORTLIST_FILE)) {
      reject(new Error(`File ${SHORTLIST_FILE} does not exist.`));
      return;
    }
    fs.createReadStream(SHORTLIST_FILE)
      .pipe(csvParser())
      .on('data', (row) => {
        entries.push(row);
      })
      .on('end', () => {
        resolve(entries);
      })
      .on('error', (err) => {
        reject(err);
      });
  });
}

// Main function
async function main() {
  try {
    await ensurePoolFile();
    const [stakedMap, shortlistEntries] = await Promise.all([
      readCsvToMap(POOL_FILE),
      readShortlist(),
    ]);
    // Read existing vote pubkeys from pool_validators.csv
    const stakedVotePubkeys = new Set(stakedMap.keys());
    // Prepare CSV writer for appending new entries
    const csvWriter = createObjectCsvWriter({
      path: POOL_FILE,
      header: headers,
      append: true,
    });
    // Prepare to write new vote pubkeys to add_to_pool.txt
    const addToPoolStream = fs.createWriteStream(ADD_TO_POOL_FILE, { flags: 'a' });
    
    let addedCount = 0; // Counter for added validators

    for (const entry of shortlistEntries) {
      const votePubkey = entry['Vote Pubkey'];
      if (!votePubkey) continue; // Skip if no vote pubkey
      if (!stakedVotePubkeys.has(votePubkey)) {
        // Add new entry to pool_validators.csv
        await csvWriter.writeRecords([entry]);
        // Append vote pubkey to add_to_pool.txt
        addToPoolStream.write(votePubkey + '\n');
        // Update the set to avoid duplicates in this run
        stakedVotePubkeys.add(votePubkey);
        addedCount++; // Increment counter
      }
      // Else, do nothing if exists
    }

    addToPoolStream.end();
    console.log(`Processing complete. Added ${addedCount} validator(s).`);
  } catch (err) {
    console.error('Error:', err);
  }
}
main();
