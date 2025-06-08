#!/bin/bash

while true; do
    # Run the commands before showing options
    node x1poolmanager.js
    node epoch-info.js

    # Add a blank line for readability
    echo

    # Display menu options
    echo "Please select an option:"
    echo "1. Fund Pool"
    echo "2. Update Pool Validators"
    echo "3. Stake to Pool Validators"
    echo "4. Unstake All Validators"
    echo "5. Withdraw from Pool"
    echo "6. Set Parameters"
    echo "7. Connect Pool"
    read -p "Enter your choice (1-7): " choice
    echo

    case "$choice" in
        1)
            echo -e "Chosen to Fund the Pool\n"
            # Add your funding logic here
            ./fundpool.sh
            ;;
        2)
            echo "Updating Pool, Prepool, and Shortlist..."
            # Add your update pool validators logic here
            ./update_pool_validators.sh
            
            ;;
        3)
            echo "Staking to Pool Validators..."
            # Add your staking logic here
            ./stake_validators.sh 
            ./update.sh 
            ;;
        4)
            echo "Unstaking and Removing all Validators from the Pool..."
            # Add your unstaking logic here
            ./remove_all_validators.sh
            ;;
        5)
            echo "Withdrawing from Pool..."
            # Add your withdrawal logic here
            ./withdraw_reserve.sh
            ;;
        6)
            echo "Setting Parameters..."
            # Add your set parameters logic here
            ./set_config.sh
            ;;
        7)
            echo "Connecting Pool..."
            # Add your connect pool logic here
            ./get_pool_keypairs.sh
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
