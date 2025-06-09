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

# Function to process user input
# Returns "-" if user inputs "-", otherwise returns the validated input
get_input() {
  local prompt="$1"
  local pattern="$2"
  local min="$3"
  local max="$4"

  read -p "$prompt" input
  if [ "$input" == "-" ]; then
    echo "-"
    return
  fi

  # Validate input based on pattern
  if ! [[ "$input" =~ $pattern ]]; then
    echo "Invalid input. Please enter a valid number or '-' to exclude."
    get_input "$prompt" "$pattern" "$min" "$max"
    return
  fi

  # For numeric inputs, check range if min and max are provided
  if [ -n "$min" ] && [ -n "$max" ]; then
    # Use bc for comparison if input is float
    if ! [[ "$input" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      echo "Invalid input. Please enter a numeric value."
      get_input "$prompt" "$pattern" "$min" "$max"
      return
    fi
    if (( $(echo "$input < $min" | bc -l) )) || (( $(echo "$input > $max" | bc -l) )); then
      echo "Input out of range ($min - $max). Please try again."
      get_input "$prompt" "$pattern" "$min" "$max"
      return
    fi
  fi

  echo "$input"
}

# Prompt for skip rate percentage
skip_rate=$(get_input "To set Stake Pool skip rate limit, enter a percentage (e.g., 10 for 10% or '-' to exclude): " '^[0-9]+(\.[0-9]+)?$' 0 100)

# Prompt for commission limit (0-100)
commission_limit=$(get_input "What is the commission limit? (0-100 or '-' to exclude): " '^[0-9]+(\.[0-9]+)?$' 0 100)

# Prompt for last epoch credit limit
credit_limit=$(get_input "Please set the stake pool last epoch credit limit (0 - 8000 or '-' to exclude): " '^[0-9]+$' 0 8000)

# Prompt for latency
latency=$(get_input "Please enter the latency (numeric value or '-' to exclude): " '^[0-9]+(\.[0-9]+)?$' '' '')

# Prompt for average credits
avg_credits=$(get_input "Please enter the average credits (0 - 8000 or '-' to exclude): " '^[0-9]+$' 0 8000)

# Prompt for minimum amount of XNT to keep in reserve
reserve=$(get_input "What is the minimum amount of XNT you wish to keep in the reserve? " '^[0-9]+(\.[0-9]+)?$' '' '')

# Prompt for delegation amount per validator
delegate=$(get_input "How much would you like to delegate to each validator? " '^[0-9]+(\.[0-9]+)?$' '' '')

# Function to update JSON with value or "-"
update_json() {
  local key="$1"
  local value="$2"
  if [ "$value" == "-" ]; then
    jq --arg val "-" ".${key} = \$val" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
  else
    # Determine if value is float or int for json
    if [[ "$value" =~ ^[0-9]+\.[0-9]+$ ]]; then
      jq --argjson val "$value" ".${key} = \$val" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    elif [[ "$value" =~ ^[0-9]+$ ]]; then
      jq --argjson val "$value" ".${key} = \$val" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    else
      # fallback to string if needed
      jq --arg val "$value" ".${key} = \$val" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
  fi
}

# Update parameters in config.json
update_json "skiprate" "$skip_rate"
update_json "last_epoch_credit_limit" "$credit_limit"
update_json "latency" "$latency"
update_json "average_credits" "$avg_credits"
update_json "reserve" "$reserve"
update_json "delegate" "$delegate"
update_json "commission" "$commission_limit"

# Set status to "current"
jq '.status = "current"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Final confirmation
echo "Configuration updated successfully:"
echo " - Skip rate limit: $skip_rate"
echo " - Commission limit: $commission_limit"
echo " - Last epoch credit limit: $credit_limit"
echo " - Latency: $latency"
echo " - Average credits: $avg_credits"
echo " - Minimum reserve (XNT): $reserve"
echo " - Delegation per validator: $delegate"
echo " - Status: current"
