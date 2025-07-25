#!/bin/bash

# Check if pool_validators.csv exists
if [ ! -f "pool_validators.csv" ]; then
  echo "File pool_validators.csv not found."
  exit 1
fi

# Count lines excluding header and empty lines
entry_count=$(awk 'NR > 1 && NF > 0' pool_validators.csv | wc -l)

if [ "$entry_count" -eq 0 ]; then
  echo "There are no validators in the pool_validators.csv"
  exit 0
fi

# Prompt the user
read -p "You are about to redistribute stake among the pool validators, Do you wish to continue? (y/n): " response

# Convert response to lowercase to handle uppercase inputs
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

if [[ "$response" == "y" ]]; then
    # Execute scripts in order
    # check redistribution amount
    ./redistribute.sh
    #calculated amended stake in current validators stakes
    ./calculate_amended.sh
    #list validators that require their stakes amending
    node amend_stake_accounts.js
    #Action the reduction in stake
    ./decrease_stake_validators.sh
    #ammend the new delegation amount to future validator shortlists
    ./new_delegate_amount.sh
    #clear validator list that had stakes reduced
    > amend_stake_accounts.txt
else
    echo "Operation cancelled."
fi
