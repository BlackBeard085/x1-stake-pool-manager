#!/usr/bin/env bash

# Script to decrease a certain amount of SOL from a stake pool, given the stake pool
# keyfile and a path to a file containing a list of validator vote accounts.
# Includes retry logic on failure and a secondary retry for failed validators.

cd "$(dirname "$0")" || exit
stake_pool_keyfile=$1
validator_list=$2
sol_amount=$3

# Path to your JSON file
json_file="pool_keypairs.json"

# Extract command path with jq
command_path=$(jq -r '.splStakePoolCommand' "$json_file")

# Expand tilde (~) to full path
full_command=$(eval echo "$command_path")

# Assign to variable
spl_stake_pool="$full_command"

# Uncomment to use a locally built CLI
# spl_stake_pool=../../../target/release/spl-stake-pool

# Set maximum retries
max_retries=5
max_retry_later=7

decrease_stakes () {
  stake_pool_pubkey=$1
  validator_list=$2
  sol_amount=$3
  while read -r validator
  do
    attempt=1
    success=false
    while [ "$attempt" -le "$max_retries" ]; do
      echo "Attempt $attempt: Decreasing stake for validator $validator"
      if $spl_stake_pool decrease-validator-stake "$stake_pool_pubkey" "$validator" "$sol_amount"; then
        echo "Successfully decreased stake for validator $validator"
        success=true
        break
      else
        echo "Failed to decrease stake for validator $validator on attempt $attempt"
        ((attempt++))
        sleep 2  # Optional: wait before retrying
      fi
    done

    if [ "$success" = false ]; then
      echo "$validator" >> failed_to_decrease_stake.txt
      echo "Logged validator $validator to failed_to_decrease_stake.txt after $max_retries attempts"
    fi
  done < "$validator_list"
}

# Retry function for failed validators
retry_failed_validators () {
  local failed_list="failed_to_decrease_stake.txt"
  if [ ! -f "$failed_list" ] || [ ! -s "$failed_list" ]; then
    echo "No failed validators to retry."
    return
  fi

  # Read validators from the failed list
  mapfile -t failed_validators < "$failed_list"

  # Clear the failed list before retrying
  > "$failed_list"

  for validator in "${failed_validators[@]}"
  do
    attempt=1
    success=false
    while [ "$attempt" -le "$max_retry_later" ]; do
      echo "Retry $attempt: Decreasing stake for validator $validator"
      if $spl_stake_pool decrease-validator-stake "$stake_pool_pubkey" "$validator" "$sol_amount"; then
        echo "Successfully decreased stake for validator $validator on retry"
        success=true
        break
      else
        echo "Failed to decrease stake for validator $validator on retry attempt $attempt"
        ((attempt++))
        sleep 2
      fi
    done

    if [ "$success" = false ]; then
      # Append again if still failed
      echo "$validator" >> failed_to_decrease_stake.txt
      echo "Validator $validator remains in failed list after retries."
    else
      echo "Validator $validator succeeded on retry and removed from failed list."
    fi
  done
}

# Main execution
stake_pool_pubkey=$(solana-keygen pubkey "$stake_pool_keyfile")
echo "Decreasing amount delegated to each validator in stake pool"

# Initial decrease attempts
decrease_stakes "$stake_pool_pubkey" "$validator_list" "$sol_amount"

# Retry failed validators up to 5 times
retry_failed_validators

echo "Process completed."
