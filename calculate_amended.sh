#!/bin/bash

# Paths to your JSON files
REDISTRIBUTE_FILE="redistribute.json"
CONFIG_FILE="config.json"

# Check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "Error: jq is not installed. Please install jq to use this script."
    exit 1
fi

# Extract RedistributionAmount from redistribute.json
redistributionAmount=$(jq -r '.redistributionAmount // empty' "$REDISTRIBUTE_FILE")
if [ -z "$redistributionAmount" ]; then
    echo "Error: 'redistributionAmount' not found in $REDISTRIBUTE_FILE"
    exit 1
fi

# Extract delegate value from config.json
delegate=$(jq -r '.delegate // empty' "$CONFIG_FILE")
if [ -z "$delegate" ]; then
    echo "Error: 'delegate' not found in $CONFIG_FILE"
    exit 1
fi

# Calculate new amended amount
amendedAmount=$(echo "$delegate - $redistributionAmount" | bc)

# Check if amendedAmount is negative
if (( $(echo "$amendedAmount < 0" | bc -l) )); then
    echo "amendedAmount is negative: $amendedAmount. Ignoring minus sign."
    # Take absolute value
    amendedAmount=$(echo "$amendedAmount" | sed 's/^-//')
fi

# Update or add amendedAmount in redistribute.json without overwriting other entries
jq --argjson amendedAmount "$amendedAmount" '.amendedAmount = $amendedAmount' "$REDISTRIBUTE_FILE" > tmp_redistribute.json && mv tmp_redistribute.json "$REDISTRIBUTE_FILE"

echo "Updated amendedAmount to $amendedAmount in $REDISTRIBUTE_FILE"
