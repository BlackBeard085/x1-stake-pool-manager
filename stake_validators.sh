#!/bin/bash

# Paths to your JSON files
POOL_KEYPAIRS_FILE="pool_keypairs.json"
CONFIG_FILE="config.json"
REDISTRIBUTE_FILE="redistribute.json"

# Check redistributionAmount in redistribute.json
REDISTRIBUTE_AMOUNT=$(jq -r '.redistributionAmount' "$REDISTRIBUTE_FILE")
if [ -z "$REDISTRIBUTE_AMOUNT" ] || [ "$REDISTRIBUTE_AMOUNT" == "null" ]; then
  echo "Error: Could not find 'redistributionAmount' in $REDISTRIBUTE_FILE"
  exit 1
fi

if (( $(echo "$REDISTRIBUTE_AMOUNT < 2" | bc -l) )); then
  echo "Redistribution stake per validator is less than 2. Please fund the pool or adjust vetting requirements to reduce pool validators. Minimum stake per validator is 2 XNT."
  exit 1
fi

# Extract the stakePoolKeypair path directly from the JSON object
STAKE_POOL_KEYPAIR=$(jq -r '.stakePoolKeypair' "$POOL_KEYPAIRS_FILE")
if [ -z "$STAKE_POOL_KEYPAIR" ] || [ "$STAKE_POOL_KEYPAIR" == "null" ]; then
  echo "Error: Could not find 'stakePoolKeypair' in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Extract the delegate amount from config.json
AMOUNT_FOR_EACH_VALIDATOR=$(jq -r '.delegate' "$CONFIG_FILE")
if [ -z "$AMOUNT_FOR_EACH_VALIDATOR" ] || [ "$AMOUNT_FOR_EACH_VALIDATOR" == "null" ]; then
  echo "Error: Could not find 'delegate' in $CONFIG_FILE"
  exit 1
fi

# Path to add_to_pool.txt (assuming it's in the current directory)
ADD_TO_POOL_FILE="add_to_pool.txt"

# Execute the command
./rebalance.sh "$STAKE_POOL_KEYPAIR" "$ADD_TO_POOL_FILE" "$AMOUNT_FOR_EACH_VALIDATOR"

echo -e "\nStaked to new validators, clearing add validator list"
> "$ADD_TO_POOL_FILE"
