#!/usr/bin/env bash

# Script to remove validators from a stake pool, given the stake pool keyfile and
# a file listing validator vote account pubkeys with retry logic and logging of failures

cd "$(dirname "$0")" || exit
stake_pool_keyfile=$1
validator_list=$2  # File containing validator vote account addresses

# Log file for failed validators
failed_log="failed_to_remove.log"

# Clear previous log if exists
> "$failed_log"

remove_validator_stakes () {
  local stake_pool=$1
  local validator_list=$2
  local max_retries=5
  local max_retry_later=7

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
      echo "Initial removal failed after $max_retries attempts: $validator" >&2
      echo "$validator" >> "$failed_log"
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

# Call the initial removal function
remove_validator_stakes "$stake_pool_pubkey" "$validator_list"

# Function to retry failed validators up to 3 times
retry_failed_validators () {
  local failed_list="failed_to_remove.log"
  if [ ! -f "$failed_list" ] || [ ! -s "$failed_list" ]; then
    echo "No failed validators to retry."
    return
  fi

  # Read failed validators into an array
  mapfile -t failed_validators < "$failed_list"

  # Clear the failed log before retrying
  > "$failed_list"

  for validator in "${failed_validators[@]}"
  do
    attempt=1
    success=0
    while [ "$attempt" -le "$max_retry_later" ]; do
      echo "Retry #$attempt for validator: $validator"
      if "$spl_stake_pool" remove-validator "$stake_pool_pubkey" "$validator"; then
        echo "Successfully removed validator: $validator on retry"
        success=1
        break
      else
        echo "Failed to remove validator: $validator on retry attempt #$attempt" >&2
        ((attempt++))
        sleep 4
      fi
    done

    if [ "$success" -eq 0 ]; then
      # Append again if still failed
      echo "$validator" >> "$failed_log"
      echo "Validator $validator remains in failed list after retries."
    else
      echo "Validator $validator succeeded on retry and removed from failed list."
    fi
  done
}

# Perform retries on failed validators
retry_failed_validators

echo "Process completed. Failed validators still logged in $failed_log"
