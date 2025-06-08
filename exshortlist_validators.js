const fs = require('fs');
const csv = require('csv-parser');
const { createObjectCsvWriter } = require('csv-writer');

// Load config.json
const config = JSON.parse(fs.readFileSync('config.json', 'utf-8'));

// Input and output files
const inputCsv = 'chain_validators.csv';
const outputCsv = 'staking_shortlist.csv';

// Prepare CSV writer
const csvWriter = createObjectCsvWriter({
  path: outputCsv,
  header: [
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
  ]
});

const shortlistedValidators = [];

// Function to check if validator meets criteria
function isValidatorEligible(validator, chainSlot, config) {
  // Parse numerical values, removing any non-numeric characters if needed
  const lastVote = parseInt(validator['Last Vote'], 10);
  const secondEpochCredits = parseInt(validator['Second Epoch Credits'].replace(/\D/g, ''), 10);
  const totalCredits = parseInt(validator['Total Credits'].replace(/\D/g, ''), 10);
  const averageCredits = parseInt(validator['Average Credits'].replace(/\D/g, ''), 10);
  const skipRateStr = validator['Skip Rate'].trim();
  const skipRate = skipRateStr.toLowerCase() === 'n/a' ? null : parseFloat(skipRateStr.replace('%', '').trim());
  const latency = parseFloat(validator['Latency']);
  const commission = parseFloat(validator['Commission']);
  const status = validator['Status'].toLowerCase();

  // Check status
  if (status !== config.status.toLowerCase()) {
    return false;
  }

  // Check last vote within 5 of chainSlot
  if (isNaN(lastVote) || Math.abs(chainSlot - lastVote) > 5) {
    return false;
  }

  // Check second epoch credits > last_epoch_credit_limit
  if (isNaN(secondEpochCredits) || secondEpochCredits <= config.last_epoch_credit_limit) {
    return false;
  }

  // Check average credits > average_credits
  if (isNaN(averageCredits) || averageCredits <= config.average_credits) {
    return false;
  }

  // Check latency <= config.latency
  if (isNaN(latency) || latency > config.latency) {
    return false;
  }

  // Check skip rate: if it's not "N/A" and >= config.skiprate, reject
  if (skipRate !== null && (isNaN(skipRate) || skipRate >= config.skiprate)) {
    return false;
  }

  // Check commission <= config.commission
  if (isNaN(commission) || commission > config.commission) {
    return false;
  }

  return true;
}

// Read CSV and process
fs.createReadStream(inputCsv)
  .pipe(csv())
  .on('data', (row) => {
    if (isValidatorEligible(row, config.chainSlot, config)) {
      shortlistedValidators.push(row);
    }
  })
  .on('end', () => {
    // Write shortlisted validators to CSV
    csvWriter
      .writeRecords(shortlistedValidators)
      .then(() => {
        console.log(`Shortlisted validators saved to ${outputCsv}`);
      })
      .catch((err) => {
        console.error('Error writing to CSV:', err);
      });
  })
  .on('error', (err) => {
    console.error('Error reading CSV:', err);
  });
