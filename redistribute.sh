#!/bin/bash

# Path to your files
CONFIG_FILE="config.json"
CSV_FILE="pool_validators.csv"
ADD_TO_POOL_FILE="add_to_pool.txt"
KEYPAIRS_FILE="pool_keypairs.json"
OUTPUT_FILE="redistribute.json"

# Extract 'delegate' value from config.json
delegate=$(jq -r '.delegate' "$CONFIG_FILE")
if [ -z "$delegate" ] || [ "$delegate" == "null" ]; then
    echo "Error: Could not extract 'delegate' from $CONFIG_FILE"
    exit 1
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
final_balance=$(awk "BEGIN {printf \"%.2f\", $total_serve_balance - ($reserve_value + (net_entries * 0.009))}")

# Divide by total number of entries
per_validator=$(awk "BEGIN {printf \"%.2f\", $final_balance / $entries_total}")

# Round down to nearest 0.01
rounded_per_validator=$(awk "BEGIN {print int($per_validator * 1000) / 1000}")

# Output the results with 'XNT' unit
echo "Total delegated: ${total_delegated} XNT"
echo "Total serve balance (before subtracting reserve): ${total_serve_balance} XNT"
echo "Final balance after subtracting reserve to delegate: ${final_balance} XNT"
echo "${entries_total}"
echo "To delegate Per validator (rounded down to 0.01): ${rounded_per_validator} XNT"

# Make sure redistribute.json exists
if [ ! -f "$OUTPUT_FILE" ] || [ ! -s "$OUTPUT_FILE" ]; then
  echo "{}" > "$OUTPUT_FILE"
fi

# Update only the redistributionAmount field in-place
jq --argjson amount "$rounded_per_validator" '.redistributionAmount = $amount' "$OUTPUT_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"
