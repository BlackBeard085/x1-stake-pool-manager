#!/usr/bin/env bash

# Script to add new validators to a stake pool, given the stake pool keyfile and
# a file listing validator vote account pubkeys

cd "$(dirname "$0")" || exit
stake_pool_keyfile=$1
validator_list=$2  # File containing validator vote account addresses, each will be added to the stake pool after creation

add_validator_stakes () {
  stake_pool=$1
  validator_list=$2
  while read -r validator
  do
    $spl_stake_pool remove-validator "$stake_pool" "$validator"
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

#spl_stake_pool=spl-stake-pool
# Uncomment to use a local build
#spl_stake_pool=../../../target/debug/spl-stake-pool

stake_pool_pubkey=$(solana-keygen pubkey "$stake_pool_keyfile")
echo "Adding validator stake accounts to the pool"
add_validator_stakes "$stake_pool_pubkey" "$validator_list"
