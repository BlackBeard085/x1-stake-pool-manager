#!/bin/bash

# Path to the JSON files
POOL_KEYPAIRS_JSON="pool_keypairs.json"
CONFIG_FILE="config.json"

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

# --- Begin added logic for balance check ---

# Extract reserveKeypair from JSON
reserveKeypair=$(jq -r '.reserveKeypair' "$POOL_KEYPAIRS_JSON")
if [ -z "$reserveKeypair" ] || [ "$reserveKeypair" == "null" ]; then
  echo "Error: reserveKeypair not found in $POOL_KEYPAIRS_JSON"
  exit 1
fi

# Get total SOL balance of reserveKeypair
total_balance=$(solana balance "$reserveKeypair" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Error: Failed to get balance for $reserveKeypair"
  exit 1
fi
balance_value=$(echo "$total_balance" | awk '{print $1}')

# Get reserve value from config.json
reserve_value=$(jq -r '.reserve' "$CONFIG_FILE")
if [ -z "$reserve_value" ] || [ "$reserve_value" == "null" ]; then
  echo "Error: reserve not found in $CONFIG_FILE"
  exit 1
fi

# Calculate available balance (balance minus reserve)
available_balance=$(echo "$balance_value - $reserve_value" | bc)

# Calculate remaining after withdrawal
remaining=$(echo "$available_balance - $amount" | bc)

# Check if withdrawal is possible (remaining >= 0.1 SOL)
comparison=$(echo "$remaining >= 0.1" | bc)
if [ "$comparison" -eq 1 ]; then
  echo "You can withdraw."
else
  echo "Insufficient balance to withdraw the requested amount."
  exit 1
fi

# --- End of balance check ---

# Construct and run the withdraw command
"$expanded_command" withdraw-sol "$pool_address" "$funding_authority" "$amount"

# Check if withdrawal was successful
if [ $? -eq 0 ]; then
    echo "Withdrawal successful. Updating initiatWithdraw to 'no' in $CONFIG_FILE."

    # Use jq to update initiatedWithdraw to "no" without affecting other data
    tmp_file=$(mktemp)
    jq '.initiatedWithdraw = "no"' "$CONFIG_FILE" > "$tmp_file" && mv "$tmp_file" "$CONFIG_FILE"
else
    echo "Withdrawal failed. Not updating the config."
fi
