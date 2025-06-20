#!/bin/bash

# Prompt the user
read -p "You are about to redistribute stake among the pool validators, Do you wish to continue? (y/n): " response

# Convert response to lowercase to handle uppercase inputs
response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

if [[ "$response" == "y" ]]; then
    # Execute scripts in order
    ./redistribute.sh
    ./calculate_reduction.sh
    node reduce_stake_accounts.js
    ./decrease_stake_validators.sh
    ./new_delegate_amount.sh
else
    echo "Operation cancelled."
fi
