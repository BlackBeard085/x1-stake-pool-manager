#!/bin/bash

# Path to the JSON file
POOL_KEYPAIRS_JSON="pool_keypairs.json"

# Function to extract a value from JSON
get_json_value() {
    local key=$1
    jq -r ".$key" "$POOL_KEYPAIRS_JSON"
}

# Read user input
read -p "How much would you like to withdraw from the reserve? " amount

# Extract necessary values from JSON
splStakePoolCommand=$(get_json_value "splStakePoolCommand")
pool_keypair=$(get_json_value "stakePoolKeypair")
funding_authority=$(get_json_value "fundingAuthorityKeypair")

# Expand ~ in splStakePoolCommand if present
# Use eval to expand the path
expanded_command=$(eval echo "$splStakePoolCommand")

# Get pool address from the pool keypair
pool_address=$(solana address -k "$pool_keypair")
if [ $? -ne 0 ]; then
    echo "Error: Failed to derive pool address from keypair $pool_keypair"
    exit 1
fi

# Construct and run the withdraw command
"$expanded_command" withdraw-sol "$pool_address" "$funding_authority" "$amount"
