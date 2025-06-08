#!/bin/bash

# Path to your JSON file
POOL_KEYPAIRS_FILE="pool_keypairs.json"

# Extract splStakePoolCommand from the JSON
splStakePoolCommand=$(jq -r '.splStakePoolCommand' "$POOL_KEYPAIRS_FILE")
if [ -z "$splStakePoolCommand" ] || [ "$splStakePoolCommand" == "null" ]; then
  echo "Error: splStakePoolCommand not found in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Extract stakePoolKeypair from the JSON
stakePoolKeypair=$(jq -r '.stakePoolKeypair' "$POOL_KEYPAIRS_FILE")
if [ -z "$stakePoolKeypair" ] || [ "$stakePoolKeypair" == "null" ]; then
  echo "Error: stakePoolKeypair not found in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Get the pool address
pooladdress=$(solana address -k "$stakePoolKeypair")
if [ $? -ne 0 ]; then
  echo "Error: Failed to get pool address from keypair $stakePoolKeypair"
  exit 1
fi

# Expand tilde in splStakePoolCommand if present
# Using bash's parameter expansion
# Note: This assumes the command is a string, possibly containing a tilde
expanded_command=$(eval echo "$splStakePoolCommand")

# Run the update command
$expanded_command update "$pooladdress"
