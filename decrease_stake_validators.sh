#!/bin/bash

# Paths to your JSON files
POOL_KEYPAIRS_FILE="pool_keypairs.json"
CONFIG_FILE="redistribute.json"

# Extract the stakePoolKeypair path directly from the JSON object
STAKE_POOL_KEYPAIR=$(jq -r '.stakePoolKeypair' "$POOL_KEYPAIRS_FILE")
if [ -z "$STAKE_POOL_KEYPAIR" ] || [ "$STAKE_POOL_KEYPAIR" == "null" ]; then
  echo "Error: Could not find 'stakePoolKeypair' in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Extract the delegate amount from config.json
AMOUNT_FOR_EACH_VALIDATOR=$(jq -r '.reductionAmount' "$CONFIG_FILE")
if [ -z "$AMOUNT_FOR_EACH_VALIDATOR" ] || [ "$AMOUNT_FOR_EACH_VALIDATOR" == "null" ]; then
  echo "Error: Could not find 'reductionAmount' in $CONFIG_FILE"
  exit 1
fi

# Path to add_to_pool.txt (assuming it's in the current directory)
REDUCE_STAKE_FILE="reduce_stake_accounts.txt"

# Execute the command
./reduce_rebalance.sh "$STAKE_POOL_KEYPAIR" "$REDUCE_STAKE_FILE" "$AMOUNT_FOR_EACH_VALIDATOR"

