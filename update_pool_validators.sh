#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Path to the JSON file containing the keypair
POOL_KEYPAIRS_FILE="pool_keypairs.json"

# Extract the stakePoolKeypair from the JSON file
stakePoolKeypair=$(jq -r '.stakePoolKeypair' "$POOL_KEYPAIRS_FILE")

# Check if jq was able to extract the keypair
if [ -z "$stakePoolKeypair" ] || [ "$stakePoolKeypair" == "null" ]; then
  echo "Error: Could not find 'stakePoolKeypair' in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Run the commands in sequence

> add_to_pool.txt
> remove_from_pool.txt

echo "Running chain_validators.js..."
node chain_validators.js

echo "Running shortlist_validators.js..."
node shortlist_validators.js

echo "Running add_to_prepool.js..."
node add_to_prepool.js

echo "Running remove_from_prepool.js..."
node remove_from_prepool.js

echo "Adding validators to pool with add-validators.sh..."
./add-validators.sh "$stakePoolKeypair" add_to_pool.txt

echo "Removing validators from pool with remove-validators.sh..."
./remove-validators.sh "$stakePoolKeypair" remove_from_pool.txt

echo "Validator pool update process completed successfully."
