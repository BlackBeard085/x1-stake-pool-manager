#!/bin/bash

# Path to your JSON file
JSON_FILE="redistribute.json"

# Check if the file exists
if [ ! -f "$JSON_FILE" ]; then
    # Do nothing if file does not exist
    exit 0
fi

# Read the redistributionAmount value
redistributionAmount=$(jq -r '.redistributionAmount // empty' "$JSON_FILE")

# Check if the value is empty
if [ -z "$redistributionAmount" ]; then
    # Do nothing if empty
    exit 0
fi

# Check if value is a number
if ! [[ "$redistributionAmount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
    # Not a number, do nothing
    exit 0
fi

# Compare the value
if (( $(echo "$redistributionAmount < 2" | bc -l) )); then
    # Print warning with amber color for "WARNING"
    amber='\033[0;33m'
    no_color='\033[0m'
    echo -e "${amber}WARNING${no_color}: Staking to new validators has stopped. Stake per validator distribution is less than 2. Please fund the pool or change vetting to reduce pool validators."
fi
