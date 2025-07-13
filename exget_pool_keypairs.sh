#!/bin/bash

# Function to prompt for a keypair path, expand it, verify existence, and store in a variable
get_keypair_path() {
    local prompt_message=$1
    local var_name=$2

    while true; do
        read -p "$prompt_message" keypair_path

        # Expand the path (handles ~ and relative paths)
        local expanded_path
        expanded_path=$(eval echo "$keypair_path")

        # Check if the file exists
        if [ -f "$expanded_path" ]; then
            # Save the valid path into a variable indirectly
            eval "$var_name='$expanded_path'"
            break
        else
            echo "File not found at '$expanded_path'. Please try again."
        fi
    done
}

# Collect all keypair paths with validation
get_keypair_path "Please enter X1 Stake Pool keypair (full path to the keypair):" stake_pool_path
get_keypair_path "Please enter Stake Pool Reserve keypair path:" reserve_path
get_keypair_path "Please enter Validator list keypair path:" validator_list_path
get_keypair_path "Please enter Mint keypair path:" mint_path
get_keypair_path "Please enter Funding authority keypair path:" funding_authority_path
get_keypair_path "Please enter Deposit authority keypair path:" deposit_authority_path

# Prompt for the preferred spl-stake-pool command
read -p "Enter your preferred spl-stake-pool command: " spl_stake_pool_command

# Save all collected data into a JSON file
cat > pool_keypairs.json <<EOF
{
  "stakePoolKeypair": "$stake_pool_path",
  "reserveKeypair": "$reserve_path",
  "validatorListKeypair": "$validator_list_path",
  "mintKeypair": "$mint_path",
  "fundingAuthorityKeypair": "$funding_authority_path",
  "depositAuthorityKeypair": "$deposit_authority_path",
  "splStakePoolCommand": "$spl_stake_pool_command"
}
EOF

echo "All data has been saved to pool_keypairs.json."
