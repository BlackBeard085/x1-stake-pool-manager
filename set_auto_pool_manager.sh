#!/bin/bash

# Define variables
CRON_COMMENT="# Auto Pool Manager cron job"

#testnet cron for every 30 mins
CRON_JOB="*/30 * * * * cd ~/x1-stake-pool-manager && ./autopoolmanager.sh # Auto Pool Manager cron job"

#mainnet cron for once per day
#CRON_JOB="0 0 * * * cd ~/x1-stake-pool-manager && ./autopoolmanager.sh # Auto Pool Manager cron job" for mainnet

# Function to add cron job
add_cron() {
    # Remove existing entries with the comment
    (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT") > current_cron
    # Add the new cron job
    echo "$CRON_JOB" >> current_cron
    # Install the new crontab
    crontab current_cron
    rm current_cron
    echo "Auto Pool Manager has been turned ON."
}

# Function to remove cron job
remove_cron() {
    # Remove entries with the comment
    (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT") | crontab -
    echo "Auto Pool Manager has been turned OFF."
    echo -e "\nResyncing pool"
    ./stake_validators.sh 
}

# Present options to the user
echo "Select an option:"
echo "1) Turn Auto Pool Manager ON"
echo "2) Turn Auto Pool Manager OFF"
read -p "Enter your choice [1 or 2]: " choice

case "$choice" in
    1)
        add_cron
        ;;
    2)
        remove_cron
        ;;
    *)
        echo "Invalid choice. Exiting."
        ;;
esac
