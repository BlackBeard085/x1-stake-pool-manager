#!/bin/bash

# Define file paths
CONFIG_FILE="config.json"
REDISTRIBUTE_FILE="redistribute.json"

# Check if files exist
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: $CONFIG_FILE not found."
  exit 1
fi

if [[ ! -f "$REDISTRIBUTE_FILE" ]]; then
  echo "Error: $REDISTRIBUTE_FILE not found."
  exit 1
fi

# Extract the redistributionAmount from redistribute.json
redistribution_amount=$(jq -r '.redistributionAmount' "$REDISTRIBUTE_FILE")
if [[ -z "$redistribution_amount" || "$redistribution_amount" == "null" ]]; then
  echo "Error: Could not find 'redistributionAmount' in $REDISTRIBUTE_FILE."
  exit 1
fi

# Update the delegate value as a number (without quotes)
jq --argjson new_delegate "$redistribution_amount" '.delegate = $new_delegate' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

echo "Updated 'delegate' in $CONFIG_FILE with numeric value: $redistribution_amount"
