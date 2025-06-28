#!/bin/bash

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
