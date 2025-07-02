#!/bin/bash

# Define variables
CRON_COMMENT="# Auto Pool Manager cron job"
CONFIG_FILE="config.json"  # Update path if needed

# Testnet cron schedule
CRON_JOB="*/30 * * * * cd ~/x1-stake-pool-manager && ./autopoolmanager.sh # Auto Pool Manager cron job"

# Mainnet cron schedule (commented out)
#CRON_JOB="0 0 * * * cd ~/x1-stake-pool-manager && ./autopoolmanager.sh # Auto Pool Manager cron job"

# Function to update epoch info and config.json
update_epoch() {
    local current_epoch
    local stored_epoch
    local epoch_in_config

    # Get current epoch from solana
    current_epoch=$(solana epoch-info --output json | jq -r '.epoch')
    if [ -z "$current_epoch" ] || [ "$current_epoch" == "null" ]; then
        echo "Failed to retrieve current epoch."
        return 1
    fi

    # Check if config.json exists
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "Config file not found at $CONFIG_FILE. Creating new config."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo "{}" > "$CONFIG_FILE"
    fi

    # Check if epoch is stored in config.json
    epoch_in_config=$(jq -r '.epoch // empty' "$CONFIG_FILE")
    if [ -z "$epoch_in_config" ]; then
        # Epoch not stored, create it
        jq --arg epoch "$current_epoch" '.epoch = ($epoch | tonumber)' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
        echo "Stored current epoch ($current_epoch) in config."
    else
        # Compare stored epoch with current epoch
        if [ "$epoch_in_config" -lt "$current_epoch" ]; then
            # Update epoch in config
            jq --arg epoch "$current_epoch" '.epoch = ($epoch | tonumber)' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
            echo "Updated epoch in config to $current_epoch."
        else
            echo "Epoch in config ($epoch_in_config) is up-to-date or ahead. No update needed."
        fi
    fi

    # Set requiredResync to "yes"
    jq '.requiredResync = "yes"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "Set requiredResync to 'yes' in config."
}

# Function to add cron job
add_cron() {
    # Remove existing entries with the comment
    (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT") > current_cron
    # Add the new cron job
    echo "$CRON_JOB" >> current_cron
    # Install the new crontab
    crontab current_cron
    rm current_cron

    # Check and update epoch info
    echo "Checking current epoch and updating config..."
    update_epoch

    echo "Auto Pool Manager has been turned ON."
}

# Function to remove cron job
remove_cron() {
    # Remove entries with the comment
    (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT") | crontab -
    echo "Auto Pool Manager has been turned OFF."
    # Optional: resync pool
    # echo -e "\nResyncing pool"
    # ./stake_validators.sh > /dev/null
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
