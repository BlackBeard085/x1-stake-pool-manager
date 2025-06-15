#!/usr/bin/env bash

# Script to add new validators to a stake pool, given the stake pool keyfile and
# a file listing validator vote account pubkeys with retry logic and success checks

cd "$(dirname "$0")" || exit
stake_pool_keyfile=$1
validator_list=$2  # File containing validator vote account addresses, each will be added to the stake pool after creation

add_validator_stakes () {
  local stake_pool=$1
  local validator_list=$2
  local max_retries=5

  while read -r validator
  do
    echo "Attempting to remove validator: $validator"

    local attempt=1
    local success=0

    until [ $attempt -gt $max_retries ]
    do
      echo "Attempt #$attempt for validator: $validator"
      if "$spl_stake_pool" remove-validator "$stake_pool" "$validator"; then
        echo "Successfully removed validator: $validator"
        success=1
        break
      else
        echo "Failed to remove validator: $validator on attempt #$attempt" >&2
        attempt=$((attempt + 1))
        sleep 2  # Optional: wait before retrying
      fi
    done

    if [ $success -eq 0 ]; then
      echo "Failed to remove validator after $max_retries attempts: $validator" >&2
    fi
  done < "$validator_list"
}

# Path to your JSON file
json_file="pool_keypairs.json"

# Extract command path with jq
command_path=$(jq -r '.splStakePoolCommand' "$json_file")

# Expand tilde (~) to full path
full_command=$(eval echo "$command_path")

# Assign to variable
spl_stake_pool="$full_command"

# Uncomment and set if you want to use a local build
# spl_stake_pool=../../../target/debug/spl-stake-pool

# Derive the stake pool's public key
stake_pool_pubkey=$(solana-keygen pubkey "$stake_pool_keyfile")
echo "Removing validator stake accounts from the pool with pubkey: $stake_pool_pubkey"

# Call the function to add validators with retry logic
add_validator_stakes "$stake_pool_pubkey" "$validator_list"
