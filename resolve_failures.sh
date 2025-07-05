#!/bin/bash

CONFIG_FILE="config.json"
AMEND_FILE="redistribute.json"
# Path to the JSON file containing the keypair
POOL_KEYPAIRS_FILE="pool_keypairs.json"
# Extract the stakePoolKeypair from the JSON file
stakePoolKeypair=$(jq -r '.stakePoolKeypair' "$POOL_KEYPAIRS_FILE")
# Check if jq was able to extract the keypair
if [ -z "$stakePoolKeypair" ] || [ "$stakePoolKeypair" == "null" ]; then
  echo "Error: Could not find 'stakePoolKeypair' in $POOL_KEYPAIRS_FILE"
  exit 1
fi
# Extract the delegate amount from config.json
AMOUNT_FOR_EACH_VALIDATOR=$(jq -r '.amendedAmount' "$AMEND_FILE")
if [ -z "$AMOUNT_FOR_EACH_VALIDATOR" ] || [ "$AMOUNT_FOR_EACH_VALIDATOR" == "null" ]; then
  echo "Error: Could not find 'amendedAmount' in $AMEND_FILE"
  exit 1
fi

echo -e "\nChecking failures adding/removing validators and increasing/decreasing validator stake"
    # Check if failed_to_remove.log has entries
    if [ -s failed_to_remove.log ]; then
      echo -e "\nEntries found in failed_to_remove.log. Running remove-validators.sh..."
        mv failed_to_remove.log resolve_failed_to_remove.log
        ./remove-validators.sh "$stakePoolKeypair" resolve_failed_to_remove.log
    else
      echo -e  "\nNo entries in failed_to_remove.log."
    fi
    # Check if failed_to_add.log has entries
    if [ -s failed_to_add.log ]; then
      echo -e  "\nEntries found in failed_to_add.log. Running add-validators.sh..."
        mv failed_to_add.log resolve_failed_to_add.log
        ./add-validators.sh "$stakePoolKeypair" resolve_failed_to_add.log
      sleep 5
    else
      echo -e  "\nNo entries in failed_to_add.log."
    fi
    # Check if failed_to_increase_stake.txt has entries
    if [ -s failed_to_increase_stake.txt ]; then
      echo -e  "\nEntries found in failed_to_increase_stake.txt. Running rebalance.sh..."
      mv failed_to_increase_stake.txt resolve_failed_to_increase_stake.txt
      ./rebalance.sh "$stakePoolKeypair" resolve_failed_to_increase_stake.txt "$AMOUNT_FOR_EACH_VALIDATOR"
    else
       echo -e "\nNo entries in failed_to_increase.log."
    fi
    # Check if failed_to_decrease_stake.txt has entries
    if [ -s failed_to_decrease_stake.txt ]; then
      echo -e "\nEntries found in failed_to_decrease_stake.txt. Running reduce_rebalance.sh..."
      mv failed_to_decrease_stake.txt resolve_failed_to_decrease_stake.txt
      ./reduce_rebalance.sh "$stakePoolKeypair" resolve_failed_to_decrease_stake.txt "$AMOUNT_FOR_EACH_VALIDATOR"
    else
       echo -e "\nNo entries in failed_to_decrease.log."
    fi
