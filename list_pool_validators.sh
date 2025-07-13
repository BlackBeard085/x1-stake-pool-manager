#!/bin/bash

# Read the JSON file to extract splStakePoolCommand and stakePoolKeypair
json_file="pool_keypairs.json"

# Extract splStakePoolCommand
splStakePoolCommand=$(jq -r '.splStakePoolCommand' "$json_file")

# Extract stakePoolKeypair
stakePoolKeypair=$(jq -r '.stakePoolKeypair' "$json_file")

# Expand the path if it contains ~
expand_path() {
  local path="$1"
  # Use 'eval' to expand ~
  eval echo "$path"
}

# Get full path to the splStakePoolCommand
full_command_path=$(expand_path "$splStakePoolCommand")

# Check if the command file exists
if [ ! -f "$full_command_path" ]; then
  echo "Error: Command file not found at $full_command_path"
  exit 1
fi

# Get the pool address
pool=$(solana address -k "$stakePoolKeypair")

# Run the command
"$full_command_path" list "$pool" -v
