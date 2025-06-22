const fs = require('fs');
const readline = require('readline');
const csv = require('csv-parser'); // Make sure to install via npm: npm install csv-parser

// File paths
const csvFilePath = 'pool_validators.csv';
const addToPoolFilePath = 'add_to_pool.txt';
const amendStakeFilePath = 'amend_stake_accounts.txt';

// Read add_to_pool.txt into a Set for quick lookup
async function loadAddToPool() {
  const addToPoolPubkeys = new Set();

  const fileStream = fs.createReadStream(addToPoolFilePath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  for await (const line of rl) {
    const pubkey = line.trim();
    if (pubkey) {
      addToPoolPubkeys.add(pubkey);
    }
  }
  return addToPoolPubkeys;
}

// Process CSV and write filtered pubkeys
async function processValidators() {
  const addToPoolPubkeys = await loadAddToPool();
  const outputStream = fs.createWriteStream(amendStakeFilePath);

  fs.createReadStream(csvFilePath)
    .pipe(csv())
    .on('data', (row) => {
      const votePubkey = row['Vote Pubkey'];
      if (votePubkey && !addToPoolPubkeys.has(votePubkey)) {
        outputStream.write(votePubkey + '\n');
      }
    })
    .on('end', () => {
      console.log(`Filtered pubkeys written to ${amendStakeFilePath}`);
      outputStream.end();
    })
    .on('error', (err) => {
      console.error('Error processing CSV:', err);
    });
}

processValidators();
