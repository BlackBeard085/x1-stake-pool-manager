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

# Prompts
skip_rate=$(prompt "To set Stake Pool skip rate limit, enter a percentage (e.g., 10 for 10%) or '-': " '^[0-9]+(\.[0-9]+)?$' 0 100)
commission_limit=$(prompt "What is the commission limit? (0-100) or '-': " '^[0-9]+(\.[0-9]+)?$' 0 100)
credit_limit=$(prompt "Please set the stake pool last epoch credit limit (0 - 8000) or '-': " '^[0-9]+$' 0 8000)
latency=$(prompt "Please enter the latency (numeric value) or '-': " '^[0-9]+(\.[0-9]+)?$' '' '')
avg_credits=$(prompt "Please enter the average credits (0 - 8000) or '-': " '^[0-9]+$' 0 8000)
reserve=$(prompt "What is the minimum amount of XNT you wish to keep in the reserve? " '^[0-9]+(\.[0-9]+)?$' '' '')
delegate=$(prompt "How much would you like to delegate to each validator? " '^[0-9]+(\.[0-9]+)?$' '' '')

# Min and max active stake
min_active_stake=$(prompt "Minimum active stake (or '-' to exclude): " '^[0-9]+(\.[0-9]+)?$' '' '')
max_active_stake=$(prompt "Maximum active stake (or '-' to exclude): " '^[0-9]+(\.[0-9]+)?' '' '')

# Update config.json
jq --argjson rate "$skip_rate" '.skiprate = $rate' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson credit "$credit_limit" '.last_epoch_credit_limit = $credit' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson lat "$latency" '.latency = $lat' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson avg "$avg_credits" '.average_credits = $avg' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson reserve "$reserve" '.reserve = $reserve' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson delegate "$delegate" '.delegate = $delegate' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson commission "$commission_limit" '.commission = $commission' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson minStake "$min_active_stake" '.min_active_stake = $minStake' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
jq --argjson maxStake "$max_active_stake" '.max_active_stake = $maxStake' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Set status to "current"
jq '.status = "current"' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"

# Final message
echo "Configuration updated successfully:"
echo " - Skip rate limit: $skip_rate%"
echo " - Commission limit: $commission_limit"
echo " - Last epoch credit limit: $credit_limit"
echo " - Latency: $latency"
echo " - Average credits: $avg_credits"
echo " - Minimum reserve (XNT): $reserve"
echo " - Delegation per validator: $delegate"
echo " - Min active stake: $min_active_stake"
echo " - Max active stake: $max_active_stake"
echo " - Status: current"
