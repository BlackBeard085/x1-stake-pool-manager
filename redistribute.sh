#!/bin/bash

# Path to your files
CONFIG_FILE="config.json"
CSV_FILE="pool_validators.csv"
KEYPAIRS_FILE="pool_keypairs.json"

# Extract 'delegate' value from config.json
delegate=$(jq -r '.delegate' "$CONFIG_FILE")
if [ -z "$delegate" ] || [ "$delegate" == "null" ]; then
    echo "Error: Could not extract 'delegate' from $CONFIG_FILE"
    exit 1
fi

# Count entries in CSV excluding header
entries=$(tail -n +2 "$CSV_FILE" | grep -c .)
if [ "$entries" -eq 0 ]; then
    echo "Error: No entries found in $CSV_FILE"
    exit 1
fi

# Calculate total delegated
total_delegated=$(awk "BEGIN {printf \"%.2f\", $delegate * $entries}")

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
per_validator=$(awk "BEGIN {printf \"%.2f\", $final_balance / $entries}")

# Round down to nearest 0.1
# Multiply by 10, floor, then divide by 10
rounded_per_validator=$(awk "BEGIN {print int($per_validator * 10) / 10}")

# Output the results with 'XNT' unit
echo "Total delegated: ${total_delegated} XNT"
echo "Total serve balance (before subtracting reserve): ${total_serve_balance} XNT"
echo "Final balance after subtracting reserve: ${final_balance} XNT"
echo "entries ${entries}"
echo "Per validator (rounded down to 0.1): ${rounded_per_validator} XNT"
