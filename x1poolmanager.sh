#!/bin/bash

./checkpoolcount.sh

while true; do
    # Run the commands before showing options
    ./update.sh > /dev/null 2>&1
    node x1poolmanager.js
    node epoch-info.js
    node failedcount.js
    echo ""
    ./stake_under_2.sh

    # Add a blank line for readability
    echo

    # Display menu options
    echo "Please select an option:"
    echo "1. Fund Pool"
    echo "2. Update Pool Validators"
    echo "3. Stake to Pool Validators"
    echo "4. Redistribute Stake"
    echo "5. Remove All Validators"
    echo "6. Withdraw from Pool"
    echo "7. Update Pool Data"
    echo "8. Set Parameters/Pool"
    echo "9. List Pool Data & Validators"
    echo "10. Setup Auto Pool Manager"
    echo "11. Resolve failures"
    echo "0. Exit"
    read -p "Enter your choice (0-10): " choice
    echo

    case "$choice" in
        1)
            echo -e "Chosen to Fund the Pool\n"
            # Add your funding logic here
            ./fundpool.sh
            ;;
        2)
            echo "Ensuring new validators delegated before updating pool"
            # Add your update pool validators logic here
            ./check_add_list.sh
            
            ;;
        3)
            echo "Staking to Pool Validators..."
            # Add your staking logic here
            ./resync_check.sh 
            sleep 5
            echo -e "\nUpdating pool." 
            ./update.sh 
            ;;
        4)
            echo "Redistributing stake"
            ./redistribute_logic.sh 
            ;;
        5)
            echo "Unstaking and Removing all Validators from the Pool..."
            # Add your unstaking logic here
            #cp pool_validators.csv pool_validators.csv.bak
            if [ -e pool_validators.csv.bak ]; then
              read -p "Backup file 'pool_validators.csv.bak' already exists. Overwrite? (y/n): " answer
              if [[ "$answer" =~ ^[Yy]$ ]]; then
                  cp pool_validators.csv pool_validators.csv.bak
                  echo "File overwritten."
               else
                  echo "Operation canceled. Backup not overwritten."
                  fi
               else
                  cp pool_validators.csv pool_validators.csv.bak
                  echo "Backup created."
               fi
            ./remove_all_validators.sh && ./update.sh
            sleep 10
            ./update.sh 
            > pool_validators.csv
            > staking_shortlist.csv
            > add_to_pool.txt
            > failed_to_decrease_stake.txt 
            > failed_to_increase_stake.txt 
            echo -e "\nSetting delegated amount to 0"
            ./replace_delegate.sh
            # Update redistributionAmount to "-"
            jq '.redistributionAmount = "-" ' redistribute.json > tmp_redistribute.json && mv tmp_redistribute.json redistribute.json
            ;;
        6)
            echo -e "\nChoose a subcommand:"
                echo -e "1. Make Withdrawl"
                echo -e "2. Initiate Withdrawl"
                read -p "Enter your choice [1-2]: " update_choice

                case $update_choice in
                    1)
                         ./withdraw_reserve.sh
                        ;;
                    2)
                        ./initiate_withdraw.sh
                        ;;
                    *)
                        echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
                        ;;
                esac
                ;;

        7)
            echo "Updating Pool data..."
            # Add your update Pool logic here
            ./update.sh
            ;;
        8)
                echo -e "\nChoose a subcommand:"
                echo -e "1. Set Vetting Parameters"
                echo -e "2. Connect Pool"
                read -p "Enter your choice [1-2]: " update_choice
                case $update_choice in
                    1)
                      echo "Setting Parameters..."
                      # Add your set parameters logic here
                      ./set_config.sh
                      ;;
                    2)
                      echo "Connecting Pool..."
                      # Add your connect pool logic here
                      ./get_pool_keypairs.sh
                      echo -e "\nImporting Pool"
                       node import_pool_val.js > /dev/null 2>&1
                      ;;
                    *)
                        echo -e "\nInvalid subcommand choice. Returning to main menu.\n"
                        ;;
                esac
                      ;;
        9)
            echo "Listing pool validators..."
            ./list_pool_validators.sh
            ;;
       10)
            echo "Opening Auto Pool Manager Setting"
            ./set_auto_pool_manager.sh
            ;;
       11)
            echo "Resolving failed adding/removing validators and increasing/decreasing validator stakes"
            ./resolve_failures.sh
            ;;
        0)
            break
            ;;
        *)
            echo "Invalid choice. Please try again."
            ;;
    esac
done
