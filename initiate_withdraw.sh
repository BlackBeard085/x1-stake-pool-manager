#!/bin/bash

# Paths to your files
POOL_KEYPAIRS_FILE="pool_keypairs.json"
CONFIG_FILE="config.json"
POOL_VALIDATORS_FILE="pool_validators.csv"
ADD_TO_POOL_FILE="add_to_pool.txt"
REDISTRIBUTE_FILE="redistribute.json"

# Prompt for withdrawal amount
read -p "How much XNT would you like to withdraw from the pool? " withdrawal_amount

# Extract reserveKeypair
reserveKeypair=$(jq -r '.reserveKeypair' "$POOL_KEYPAIRS_FILE")
if [ -z "$reserveKeypair" ] || [ "$reserveKeypair" == "null" ]; then
  echo "Error: reserveKeypair not found in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Get the total SOL balance
total_balance=$(solana balance "$reserveKeypair" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Error: Failed to get balance for $reserveKeypair"
  exit 1
fi

balance_value=$(echo "$total_balance" | awk '{print $1}')

# Get reserve value from config.json
reserve_value=$(jq -r '.reserve' "$CONFIG_FILE")
if [ -z "$reserve_value" ] || [ "$reserve_value" == "null" ]; then
  echo "Error: reserve not found in $CONFIG_FILE"
  exit 1
fi

# Calculate available balance
available_balance=$(echo "$balance_value - $reserve_value" | bc)

# Calculate remaining after withdrawal
remaining=$(echo "$available_balance - $withdrawal_amount" | bc)

# Check if withdrawal is possible
comparison=$(echo "$remaining >= 0.1" | bc)
if [ "$comparison" -eq 1 ]; then
  echo "You can withdraw."
else
  echo "Insufficient balance to withdraw the requested amount."

  # Update initiatedWithdraw to "yes" in config.json
  jq 'if has("initiatedWithdraw") then . else . + {"initiatedWithdraw":"yes"} end' "$CONFIG_FILE" > tmp_config.json && mv tmp_config.json "$CONFIG_FILE"

  echo "initiating withdrawal"

  # Calculate net entries
  total_entries=$(($(wc -l < "$POOL_VALIDATORS_FILE") - 1))
  add_entries=$(grep -v '^$' "$ADD_TO_POOL_FILE" | wc -l)
  net_entries=$((total_entries - add_entries))
  
  # Handle special case: zero entries
  if [ "$total_entries" -eq 0 ] || [ "$net_entries" -eq 0 ]; then
    echo "Pool has insufficient funds to process this withdrawal and keep the minimum reserve balance. Either reduce the minimum reserve balance or request a smaller amount to withdraw."
    exit 1
  fi

  # Calculate raw amount and amendedAmount
  raw_amount=$(echo "scale=10; $withdrawal_amount / $net_entries" | bc)
  amendedAmount=$(awk -v val="$raw_amount" 'BEGIN {
      printf "%.4f", ( (val * 10000) == int(val * 10000) ? val : (int(val * 10000 + 0.9999))/10000 )
  }')

  # Check if amendedAmount is negative
  if (( $(echo "$amendedAmount < 0" | bc -l) )); then
    echo "Pool has insufficient funds to process this withdrawl and keep the minimum reserve balance. Either reduce the minimum reserve balance or request a smaller amount to withdraw."
    exit 1
  fi

  # Save amendedAmount in redistribute.json
  if [ -f "$REDISTRIBUTE_FILE" ]; then
    jq --arg amt "$amendedAmount" '.amendedAmount = ($amt | tonumber)' "$REDISTRIBUTE_FILE" > tmp_redistribute.json
  else
    echo "{}" > "$REDISTRIBUTE_FILE"
    jq --arg amt "$amendedAmount" '. + {amendedAmount: ($amt | tonumber)}' "$REDISTRIBUTE_FILE" > tmp_redistribute.json
  fi
  mv tmp_redistribute.json "$REDISTRIBUTE_FILE"

  echo "Final amendedAmount (rounded to 0.0001): $amendedAmount"

  # Extract delegate value
  delegate_value=$(jq -r '.delegate' "$CONFIG_FILE")
  if [ -z "$delegate_value" ] || [ "$delegate_value" == "null" ]; then
    echo "Error: delegate not found in $CONFIG_FILE"
    exit 1
  fi

  # Calculate redistributionAmount
  redistributionAmount=$(echo "$delegate_value - $amendedAmount" | bc)

  # Save redistributionAmount in redistribute.json
  if [ -f "$REDISTRIBUTE_FILE" ]; then
    jq --arg redisAmt "$redistributionAmount" '.redistributionAmount = ($redisAmt | tonumber)' "$REDISTRIBUTE_FILE" > tmp_redistribute.json
  else
    echo "{}" > "$REDISTRIBUTE_FILE"
    jq --arg redisAmt "$redistributionAmount" '. + {redistributionAmount: ($redisAmt | tonumber)}' "$REDISTRIBUTE_FILE" > tmp_redistribute.json
  fi
  mv tmp_redistribute.json "$REDISTRIBUTE_FILE"

  # Save requested withdrawal
  jq --arg req "$withdrawal_amount" '.requestedWithdrawal = ($req | tonumber)' "$REDISTRIBUTE_FILE" > tmp_redistribute.json
  mv tmp_redistribute.json "$REDISTRIBUTE_FILE"

  echo "redistributionAmount set to: $redistributionAmount"
  echo "requestedWithdrawal set to: $withdrawal_amount"
fi
