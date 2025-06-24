#!/bin/bash

CONFIG_FILE="config.json"

# Fetch current epoch from solana
CURRENT_EPOCH=$(solana epoch-info --output=json | jq -r '.epoch')

# Check if config.json exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

# Check if 'epoch' exists in config.json
EXISTING_EPOCH=$(jq -r '.epoch // empty' "$CONFIG_FILE")

if [ -z "$EXISTING_EPOCH" ]; then
  # No epoch in config.json, add it
  jq --arg epoch "$CURRENT_EPOCH" '. + {epoch: ($epoch | tonumber)}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  echo "Epoch added to config.json: $CURRENT_EPOCH"
else
  # Epoch exists, compare
  if [ "$EXISTING_EPOCH" -ne "$CURRENT_EPOCH" ]; then
    # Update epoch
    jq --arg epoch "$CURRENT_EPOCH" '.epoch = ($epoch | tonumber)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    echo "Epoch updated in config.json: $CURRENT_EPOCH"
    echo -e "\nRunning Stake Pool Manager"
    echo -e "Updating Pool\n"
    ./update.sh
    sleep 5
    echo -e "Staking to awaiting validators\n"
    ./stake_validators.sh 
    sleep 5
    echo -e "Updating pool with top performing validators\n"
    ./update_pool_validators.sh
    sleep 5
    echo -e "Checking possible stake redistribution options"
    node autocheckreserve.js
    echo -e "\nAuto Pool manager complete"
  else
    echo "Epoch in config.json is already up-to-date: $EXISTING_EPOCH"
  fi
fi
