#!/bin/bash

# Path to your scripts and config
CONFIG_FILE="config.json"
AUTOPOLLMANAGER_CRON=$(crontab -l | grep -F "autopoolmanager.sh")
CURRENT_EPOCH=$(solana epoch-info | grep -oP '(?<=Epoch: )\d+')
# Or if solana epoch-info outputs in a different format, adjust accordingly

# Check if autopoolmanager.sh cronjob exists
if [[ -n "$AUTOPOLLMANAGER_CRON" ]]; then
    echo "please turn off auto pool manager before staking"
    exit 0
fi

# Check if config.json exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Config file not found!"
    exit 1
fi

# Check requiredResync value
REQUIRED_RESYNC=$(jq -r '.requiredResync' "$CONFIG_FILE")

if [ "$REQUIRED_RESYNC" == "yes" ]; then
    # Get stored epoch from config
    STORED_EPOCH=$(jq -r '.epoch' "$CONFIG_FILE")
    
    if [ "$CURRENT_EPOCH" -gt "$STORED_EPOCH" ]; then
        # Run stake_validators.sh
        ./stake_validators.sh

        # Update epoch and requiredResync in config.json
        jq --argjson new_epoch "$CURRENT_EPOCH" '.epoch = $new_epoch | .requiredResync = "no"' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"

        echo "Resync complete"
    elif [ "$CURRENT_EPOCH" -eq "$STORED_EPOCH" ]; then
        echo "Await next epoch to resync"
    else
        # Current epoch is less than stored epoch (unlikely), handle as needed
        echo "Current epoch is less than stored epoch. Check system time."
    fi
elif [ "$REQUIRED_RESYNC" == "no" ]; then
    # Run checkreserve.js
    node checkreserve.js
fi
