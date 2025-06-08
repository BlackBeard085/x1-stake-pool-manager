#!/bin/bash

CONFIG_FILE="config.json"

# Check if config.json exists; if not, create an empty JSON object
if [ ! -f "$CONFIG_FILE" ]; then
  echo "{}" > "$CONFIG_FILE"
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed. Please install jq and rerun the script."
  exit 1
fi

# Prompt for skip rate percentage
read -p "To set Stake Pool skip rate limit, enter a percentage (e.g., 10 for 10%): " skip_rate
if ! [[ "$skip_rate" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$skip_rate < 0" | bc -l) )) || (( $(echo "$skip_rate > 100" | bc -l) )); then
  echo "Invalid input. Please enter a number between 0 and 100."
  exit 1
fi

# Prompt for commission limit (0-100)
read -p "What is the commission limit? (0-100): " commission_limit
if ! [[ "$commission_limit" =~ ^[0-9]+(\.[0-9]+)?$ ]] || (( $(echo "$commission_limit < 0" | bc -l) )) || (( $(echo "$commission_limit > 100" | bc -l) )); then
  echo "Invalid input. Please enter a number between 0 and 100."
  exit 1
fi

# Prompt for last epoch credit limit
read -p "Please set the stake pool last epoch credit limit (0 - 8000): " credit_limit
if ! [[ "$credit_limit" =~ ^[0-9]+$ ]] || (( credit_limit < 0 )) || (( credit_limit > 8000 )); then
  echo "Invalid input. Please enter an integer between 0 and 8000."
  exit 1
fi

# Prompt for latency
read -p "Please enter the latency (numeric value): " latency
if ! [[ "$latency" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid input. Please enter a numeric value for latency."
  exit 1
fi

# Prompt for average credits
read -p "Please enter the average credits (0 - 8000): " avg_credits
if ! [[ "$avg_credits" =~ ^[0-9]+$ ]] || (( avg_credits < 0 )) || (( avg_credits > 8000 )); then
  echo "Invalid input. Please enter an integer between 0 and 8000."
  exit 1
fi

# Prompt for minimum amount of XNT to keep in reserve
read -p "What is the minimum amount of XNT you wish to keep in the reserve? " reserve
if ! [[ "$reserve" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid input. Please enter a numeric value."
  exit 1
fi

# Prompt for delegation amount per validator
read -p "How much would you like to delegate to each validator? " delegate
if ! [[ "$delegate" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Invalid input. Please enter a numeric value."
  exit 1
fi

# Update parameters in config.json
jq --argjson rate "$skip_rate" '.skiprate = $rate' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson credit "$credit_limit" '.last_epoch_credit_limit = $credit' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson lat "$latency" '.latency = $lat' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson avg "$avg_credits" '.average_credits = $avg' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson reserve "$reserve" '.reserve = $reserve' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson delegate "$delegate" '.delegate = $delegate' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson commission "$commission_limit" '.commission = $commission' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Set status to "current"
jq '.status = "current"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Final confirmation
echo "Configuration updated successfully:"
echo " - Skip rate limit: $skip_rate%"
echo " - Commission limit: $commission_limit"
echo " - Last epoch credit limit: $credit_limit"
echo " - Latency: $latency"
echo " - Average credits: $avg_credits"
echo " - Minimum reserve (XNT): $reserve"
echo " - Delegation per validator: $delegate"
echo " - Status: current"
