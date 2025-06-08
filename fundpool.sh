#!/bin/bash

# Prompt the user for the funding amount
read -p "How much funds would you like to add to the pool? " amount

# Load variables from pool_keypairs.json
splStakePoolCommand=$(jq -r '.splStakePoolCommand' pool_keypairs.json)
fundingAuthorityKeypair=$(jq -r '.fundingAuthorityKeypair' pool_keypairs.json)
stakePoolKeypair=$(jq -r '.stakePoolKeypair' pool_keypairs.json)

# Expand the splStakePoolCommand path if it contains ~
# Convert to absolute path
splStakePoolCommand=$(eval echo "$splStakePoolCommand")

# Check if the command exists
if [ ! -f "$splStakePoolCommand" ]; then
  echo "Error: splStakePoolCommand not found at path: $splStakePoolCommand"
  exit 1
fi

# Get the pool address from the stake pool keypair
pool_address=$(solana address -k "$stakePoolKeypair")

# Execute the command
"$splStakePoolCommand" deposit-sol --funding-authority "$fundingAuthorityKeypair" "$pool_address" "$amount"
