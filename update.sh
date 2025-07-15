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

# Retry logic parameters
MAX_RETRIES=5
RETRY_COUNT=0
SLEEP_INTERVAL=2  # seconds

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  echo "Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES..."
  
  # Run the update command
  $expanded_command update "$pooladdress"
  
  # Check if command succeeded
  if [ $? -eq 0 ]; then
    echo ""
    break
  else
    echo "Update failed."
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
      echo "Retrying in $SLEEP_INTERVAL seconds..."
      sleep $SLEEP_INTERVAL
    else
      echo "Max retries reached. Exiting."
      exit 1
    fi
  fi
done
