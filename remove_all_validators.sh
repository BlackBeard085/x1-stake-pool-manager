#!/bin/bash

# Exit on error
set -e

# Define filenames
CSV_FILE="pool_validators.csv"
KEYPAIRS_FILE="pool_keypairs.json"
REMOVE_LIST_FILE="remove-list.txt"

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
  echo "Error: CSV file '$CSV_FILE' not found."
  exit 1
fi

# Check if keypairs JSON exists
if [ ! -f "$KEYPAIRS_FILE" ]; then
  echo "Error: JSON file '$KEYPAIRS_FILE' not found."
  exit 1
fi

# Extract the stake pool keypair from JSON
STAKE_POOL=$(jq -r '.stakePoolKeypair' "$KEYPAIRS_FILE")
if [ "$STAKE_POOL" == "null" ] || [ -z "$STAKE_POOL" ]; then
  echo "Error: 'stakePoolKeypair' not found in '$KEYPAIRS_FILE'."
  exit 1
fi

echo "Using stake pool keypair: $STAKE_POOL"

# Extract Vote Pubkeys from CSV and write to remove-list.txt
# Assumes CSV headers are exactly as specified and no commas within fields
# Skip the header line and extract the Vote Pubkey column
awk -F',' 'NR>1 {print $1}' "$CSV_FILE" > "$REMOVE_LIST_FILE"

echo "Extracted vote pubkeys to '$REMOVE_LIST_FILE'."

# Run the remove-validators.sh script
./remove-validators.sh "$STAKE_POOL" "$REMOVE_LIST_FILE"

> remove-list.txt
echo "Removal command executed."
