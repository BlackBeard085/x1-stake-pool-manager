#!/bin/bash
# Path to your files
CONFIG_FILE="config.json"
CSV_FILE="pool_validators.csv"
ADD_TO_POOL_FILE="add_to_pool.txt"
KEYPAIRS_FILE="pool_keypairs.json"
OUTPUT_FILE="redistribute.json"

# Check and fix 'delegate' in config.json if empty or '-'
delegate=$(jq -r '.delegate' "$CONFIG_FILE")
if [ -z "$delegate" ] || [ "$delegate" == "null" ] || [ "$delegate" == "-" ]; then
  # Replace 'delegate' value with 0 in config.json
  jq '.delegate = 0' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  delegate=0
fi

# Extract 'delegate' value again after potential fix
delegate=$(jq -r '.delegate' "$CONFIG_FILE")
# Determine if delegate is empty, null, or '-'
if [ -z "$delegate" ] || [ "$delegate" == "null" ] || [ "$delegate" == "-" ] || [ "$delegate" == "0" ]; then
    # If delegate is empty, null, dash, or zero, consider increasing all delegations
    delegate_value_flag=true
else
    delegate_value_flag=false
fi

# Count entries in CSV excluding header
entries_total=$(tail -n +2 "$CSV_FILE" | grep -c .)

# Count entries in add_to_pool.txt
entries_in_add=$(wc -l < "$ADD_TO_POOL_FILE")

# Calculate net entries
net_entries=$(( entries_total - entries_in_add ))
if [ "$net_entries" -lt 0 ]; then
    echo "Warning: net entries negative ($net_entries). Setting to 0."
    net_entries=0
fi

# Calculate total delegated based on net entries
total_delegated=$(awk "BEGIN {printf \"%.2f\", $delegate * $net_entries}")

# Extract 'reserveKeypair' from pool_keypairs.json
reserveKeypair=$(jq -r '.reserveKeypair' "$KEYPAIRS_FILE")
if [ -z "$reserveKeypair" ] || [ "$reserveKeypair" == "null" ]; then
    echo "Error: Could not extract 'reserveKeypair' from $KEYPAIRS_FILE"
    exit 1
fi

# Run solana balance command
balance_output=$(solana balance "$reserveKeypair" 2>/dev/null)
if [ $? -ne 0 ] || [ -z "$balance_output" ]; then
    echo "Error: Failed to get balance for reserveKeypair"
    exit 1
fi

# Extract SOL balance
sol_balance=$(echo "$balance_output" | awk '{print $1}')

# Extract 'reserve' value from config.json
reserve_value=$(jq -r '.reserve' "$CONFIG_FILE")
if [ -z "$reserve_value" ] || [ "$reserve_value" == "null" ]; then
    echo "Error: Could not extract 'reserve' from $CONFIG_FILE"
    exit 1
fi

# Calculate total serve balance (before subtracting reserve)
total_serve_balance=$(awk "BEGIN {printf \"%.2f\", $total_delegated + $sol_balance}")

# Subtract reserve value
final_balance=$(awk "BEGIN {printf \"%.2f\", $total_serve_balance - $reserve_value}")

# Divide by total number of entries
per_validator=$(awk "BEGIN {printf \"%.2f\", $final_balance / $entries_total}")

# Round down to nearest 0.01
rounded_per_validator=$(awk "BEGIN {print int($per_validator * 100) / 100}")

# Output the results
echo "Total delegated: ${total_delegated} XNT"
echo "Total reserve balance (before subtracting min reserve): ${total_serve_balance} XNT"
echo "Final balance after subtracting reserve to delegate: ${final_balance} XNT"
echo "${entries_total}"
echo "To delegate Per validator (rounded down to 0.01): ${rounded_per_validator} XNT"

# Make sure redistribute.json exists
if [ ! -f "$OUTPUT_FILE" ] || [ ! -s "$OUTPUT_FILE" ]; then
  echo "{}" > "$OUTPUT_FILE"
fi

# Update only the redistributionAmount field in-place
jq --argjson amount "$rounded_per_validator" '.redistributionAmount = $amount' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

# --- New addition: Calculate the increase per validator ---

# Extract redistributionAmount from redistribute.json
redistribution_amount=$(jq -r '.redistributionAmount' "$OUTPUT_FILE")
if [ -z "$redistribution_amount" ] || [ "$redistribution_amount" == "null" ]; then
    echo "Error: Could not extract 'redistributionAmount' from $OUTPUT_FILE"
    exit 1
fi

# Check if per validator amount is less than 2
if (( $(echo "$redistribution_amount < 2" | bc -l) )); then
    echo -e "\nStake per validator is less than 2. Please fund the pool or adjust vetting requirements to reduce pool validators. Minimum stake per validator is 2 XNT"
    exit 0
fi

# Calculate increase over delegate
increase=$(awk "BEGIN {printf \"%.2f\", $redistribution_amount - $delegate}")

# Output the increase
echo "Each validator will receive an increase of: ${increase} XNT over the delegate value in config.json"

# --- Determine if increasing all delegations is worth it ---
if [ "$delegate_value_flag" = true ]; then
    # Delegate value is empty, zero, or '-'
    echo -e "\nValidators have 0 stake. It is worth increasing all delegations.\n"
    echo -e "Increasing pool validator stake\n"
      ./increase_redistribute_logic.sh
#    echo -e "\nStaking to new pool validators"
#       ./stake_validators.sh
elif (( $(echo "$increase > 1.00" | bc -l) )); then
    echo -e "\nIt is worth increasing all delegations\n"
    echo -e "Increasing pool validator stake\n"
    ./increase_redistribute_logic.sh
    echo -e "\nIncreased stake to existing pool validators"
#    ./stake_validators.sh
else
    echo "It is not worth increasing all delegations, can continue to delegate only to new pool entered validators"
#    ./stake_validators.sh
fi
