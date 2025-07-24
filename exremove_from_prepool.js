// manage_pool_validators.js

const fs = require('fs');
const csvParser = require('csv-parser');
const { createObjectCsvWriter } = require('csv-writer');

const POOL_FILE = 'pool_validators.csv';
const SHORTLIST_FILE = 'staking_shortlist.csv';
const REMOVE_FROM_POOL_FILE = 'remove_from_pool.txt';

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

// Function to read CSV into a Map keyed by Vote Pubkey
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

// Function to read CSV into an array for processing
function readCsvToArray(filePath) {
  return new Promise((resolve, reject) => {
    const entries = [];
    if (!fs.existsSync(filePath)) {
      resolve(entries);
      return;
    }
    fs.createReadStream(filePath)
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
    // Read current pool validators
    const poolEntries = await readCsvToArray(POOL_FILE);
    // Read shortlist
    const shortlistMap = await readCsvToMap(SHORTLIST_FILE);

    // Build a new array for entries to keep
    const entriesToKeep = [];
    const removedVotePubkeys = [];

    for (const entry of poolEntries) {
      const votePubkey = entry['Vote Pubkey'];
      if (votePubkey && shortlistMap.has(votePubkey)) {
        // Keep this entry
        entriesToKeep.push(entry);
      } else {
        // Mark for removal
        if (votePubkey) {
          removedVotePubkeys.push(votePubkey);
        }
      }
    }

    // Write back the filtered entries to pool_validators.csv
    const csvWriter = createObjectCsvWriter({
      path: POOL_FILE,
      header: headers,
    });
    await csvWriter.writeRecords(entriesToKeep);

    // Append removed vote pubkeys to remove_from_pool.txt
    const removeStream = fs.createWriteStream(REMOVE_FROM_POOL_FILE, { flags: 'a' });
    for (const pubkey of removedVotePubkeys) {
      removeStream.write(pubkey + '\n');
    }
    removeStream.end();

    console.log('Pool validation management complete.');
    console.log(`Removed ${removedVotePubkeys.length} entries.`);
  } catch (err) {
    console.error('Error:', err);
  }
}

main();
