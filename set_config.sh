#!/bin/bash

CONFIG_FILE="config.json"

# Initialize config.json if missing
if [ ! -f "$CONFIG_FILE" ]; then
  echo "{}" > "$CONFIG_FILE"
fi

# Check jq
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed."
  exit 1
fi

# Function to prompt with validation
prompt() {
  local prompt_text="$1"
  local pattern="$2"
  local min="$3"
  local max="$4"
  local input
  while true; do
    read -p "$prompt_text" input
    if [ "$input" == "-" ]; then
      echo "-"
      return
    fi
    if [[ "$input" =~ $pattern ]]; then
      # Range check if applicable
      if [ -n "$min" ] && [ -n "$max" ]; then
        if ! [[ "$input" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
          echo "Invalid numeric input."
          continue
        fi
        if (( $(echo "$input < $min" | bc -l) )) || (( $(echo "$input > $max" | bc -l) )); then
          echo "Input out of range ($min - $max)."
          continue
        fi
      fi
      echo "$input"
      break
    else
      echo "Invalid input format."
    fi
  done
}

# Collect inputs
echo -e "\nEnter a value for each parameter or '-' to exclude the metric from vetting \n"

skip_rate=$(prompt "Enter the maximum skip rate a validator can have (e.g., 10 for 10%): " '^[0-9]+(\.[0-9]+)?$' 0 100)
commission_limit=$(prompt "Enter the maximum commission the validator can charge: " '^[0-9]+(\.[0-9]+)?$' 0 100)
min_active_stake=$(prompt "Enter the minimum active stake requirement: " '^[0-9]+(\.[0-9]+)?$' '' '')
max_active_stake=$(prompt "Enter the maximum active stake requirment: " '^[0-9]+(\.[0-9]+)?$' '' '')
credit_limit=$(prompt "Enter the last full epoch credit requirement (0 - 8000): " '^[0-9]+$' 0 8000)

# New prompt for total_credits
total_credits=$(prompt "What is the minimum Total Credits requirement: " '^[0-9]+$' 0 1000000000)

latency=$(prompt "Please enter the minimum latency requirement: " '^[0-9]+(\.[0-9]+)?$' '' '')
avg_credits=$(prompt "Please enter the Validator average credits requirement (0 - 8000): " '^[0-9]+$' 0 8000)
reserve=$(prompt "What is the minimum amount of XNT you wish to keep in the reserve? " '^[0-9]+(\.[0-9]+)?$' '' '')
delegate=$(prompt "How much would you like to delegate to each validator? " '^[0-9]+(\.[0-9]+)?$' '' '')

# Function to update JSON with either number or string
update_json() {
  local key="$1"
  local value="$2"
  if [ "$value" == "-" ]; then
    # Update with string "-"
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  else
    # Update with numeric value
    jq --arg key "$key" --argjson value "$value" '.[$key] = $value' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  fi
}

# Update config.json with each parameter
update_json "skiprate" "$skip_rate"
update_json "last_epoch_credit_limit" "$credit_limit"
update_json "min_active_stake" "$min_active_stake"
update_json "max_active_stake" "$max_active_stake"
update_json "total_credits" "$total_credits"     # Added this line
update_json "latency" "$latency"
update_json "average_credits" "$avg_credits"
update_json "reserve" "$reserve"
update_json "delegate" "$delegate"
update_json "commission" "$commission_limit"

# Set status to "current"
jq '.status = "current"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Final message
echo "Configuration updated successfully:"
echo " - Skip rate limit: $skip_rate%"
echo " - Commission limit: $commission_limit"
echo " - Min active stake: $min_active_stake"
echo " - Max active stake: $max_active_stake"
echo " - Total credits requirement: $total_credits"      # Added this line
echo " - Last epoch credit limit: $credit_limit"
echo " - Latency: $latency"
echo " - Average credits: $avg_credits"
echo " - Minimum reserve (XNT): $reserve"
echo " - Delegation per validator: $delegate"
echo " - Status: current"
