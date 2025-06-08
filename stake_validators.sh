#!/bin/bash

# Usage: ./script.sh <stake-pool-keypair> <add_to_pool.txt>

# Check if required arguments are provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <stake-pool-keypair> <add_to_pool.txt>"
  exit 1
fi

STAKE_POOL_KEYPAIR="$1"
ADD_TO_POOL_FILE="$2"

# Extract the 'delegate' value from config.json
# Assumes config.json is in the current directory
AMOUNT=$(jq -r '.delegate' config.json)

# Check if jq succeeded
if [ -z "$AMOUNT" ] || [ "$AMOUNT" == "null" ]; then
  echo "Error: Could not extract 'delegate' from config.json"
  exit 1
fi

# Run the rebalance command
./rebalance.sh "$STAKE_POOL_KEYPAIR" "$ADD_TO_POOL_FILE" "$AMOUNT"

> add_to_pool.txt
> remove_from_pool.txt
