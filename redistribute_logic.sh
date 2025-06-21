#!/bin/bash

# Prompt the user
read -p "You are about to redistribute stake among the pool validators, Do you wish to continue? (y/n): " response

# Convert response to lowercase to handle uppercase inputs
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

if [[ "$response" == "y" ]]; then
    # Execute scripts in order
    # check redistribution amount
    ./redistribute.sh
    #calculated reduction in current validators stakes
    ./calculate_reduction.sh
    #list validators that require their stakes reducings
    node reduce_stake_accounts.js
    #Action the reduction in stake
    ./decrease_stake_validators.sh
    #amend the new delegation amount to future validator shortlists
    ./new_delegate_amount.sh
    #clear validator list that had stakes reduced
    > reduce_stake_accounts.txt
else
    echo "Operation cancelled."
fi
