const fs = require('fs');
const { execSync } = require('child_process');

// Paths to your files
const addToPoolPath = 'add_to_pool.txt';
const configPath = 'config.json';
const poolKeypairsPath = 'pool_keypairs.json';

// Step 1: Count entries in add_to_pool.txt
const addToPoolContent = fs.readFileSync(addToPoolPath, 'utf8');
const entriesCount = addToPoolContent.split(/\r?\n/).filter(line => line.trim() !== '').length;

// Step 2: Read config.json
const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
const delegate = config.delegate;
const reserveConfig = config.reserve; // assuming reserve value is stored here

// Step 3: Calculate required-amount
const requiredAmount = entriesCount * delegate;
console.log(`Entries count: ${entriesCount}`);
console.log(`Delegate value: ${delegate}`);
console.log(`Required amount: ${requiredAmount}`);

// Step 4: Read reserveKeypair from pool_keypairs.json
const poolKeypairs = JSON.parse(fs.readFileSync(poolKeypairsPath, 'utf8'));
const reserveKeypairPath = poolKeypairs.reserveKeypair; // ensure this key exists

// Step 5: Get the reserve balance using solana CLI
let reserveBalance = 0;
try {
    const command = `solana balance ${reserveKeypairPath}`;
    const output = execSync(command, { encoding: 'utf8' }).trim();
    // Output is like: '123.456 SOL'
    const match = output.match(/^([\d.,]+)\s*SOL$/);
    if (match) {
        reserveBalance = parseFloat(match[1].replace(/,/g, ''));
    } else {
        console.error('Could not parse balance output.');
        process.exit(1);
    }
} catch (error) {
    console.error('Error executing solana balance command:', error);
    process.exit(1);
}

// Step 6: Calculate postDelegationReserve
const postDelegationReserve = reserveBalance - requiredAmount;
console.log(`Reserve balance: ${reserveBalance} SOL`);
console.log(`Post Delegation Reserve (reserve - required-amount): ${postDelegationReserve} SOL`);

// Step 7: Compare postDelegationReserve with reserve from config.json
if (postDelegationReserve > reserveConfig) {
    console.log(`Can delegate: Post delegation reserve (${postDelegationReserve} SOL) is higher than reserve (${reserveConfig} SOL).`);
} else {
    console.log(`Increase reserve before delegations: Post delegation reserve (${postDelegationReserve} SOL) is less than reserve (${reserveConfig} SOL).`);
}
