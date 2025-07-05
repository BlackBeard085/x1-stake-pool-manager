#!/bin/bash

#export solana node jq and cargo PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

LOG_FILE="auto_pool_manager.log"
CONFIG_FILE="config.json"

# Check if log file exists and its size, truncate if larger than 1GB
if [ -f "$LOG_FILE" ]; then
  LOG_SIZE=$(stat -c%s "$LOG_FILE")
  if [ "$LOG_SIZE" -gt 1073741824 ]; then
    > "$LOG_FILE"
  fi
fi

# Function to log messages with timestamp
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if config.json exists
if [ ! -f "$CONFIG_FILE" ]; then
  log "Error: $CONFIG_FILE not found."
  exit 1
fi

# Check if 'initiatedWithdraw' exists and its value
INITIATED_WITHDRAW=$(jq -r '.initiatedWithdraw // empty' "$CONFIG_FILE")

if [ "$INITIATED_WITHDRAW" == "yes" ]; then
  log "A withdrawal has been initiated. Auto pool manager is paused till withdrawal has been processed."
  exit 0
fi

# Fetch current epoch from solana
CURRENT_EPOCH=$(solana epoch-info --output=json | jq -r '.epoch')
log "Current epoch fetched: $CURRENT_EPOCH"

# Check if 'epoch' exists in config.json
EXISTING_EPOCH=$(jq -r '.epoch // empty' "$CONFIG_FILE")
if [ -z "$EXISTING_EPOCH" ]; then
  # No epoch in config.json, add it
  jq --arg epoch "$CURRENT_EPOCH" '. + {epoch: ($epoch | tonumber)}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  log "Epoch added to config.json: $CURRENT_EPOCH"
else
  # Epoch exists, compare
  if [ "$EXISTING_EPOCH" -ne "$CURRENT_EPOCH" ]; then
    # Update epoch
    jq --arg epoch "$CURRENT_EPOCH" '.epoch = ($epoch | tonumber)' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    log "Epoch updated in config.json: $CURRENT_EPOCH"
    
    # Run procedures and log output
    log "Running Stake Pool Manager"
    
    log "Updating Pool"
    ./update.sh 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    log "Staking to awaiting validators"
    ./stake_validators.sh 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    log "Updating pool with top performing validators"
    ./update_pool_validators.sh 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    log "Checking possible stake redistribution options"
    node autocheckreserve.js 2>&1 | tee -a "$LOG_FILE"
    
    log "Auto Pool manager complete"
  else
    log "Epoch in config.json is already up-to-date: $EXISTING_EPOCH"
    log "Checking failures adding/removing validators and increasing/decreasing validator stake"

# Check if failed_to_remove.log has entries
if [ -s failed_to_remove.log ]; then
  echo "Entries found in failed_to_remove.log. Running remove-validators.sh..."
  ./remove-validators.sh
fi

# Check if failed_to_add.log has entries
if [ -s failed_to_add.log ]; then
  echo "Entries found in failed_to_add.log. Running add-validators.sh..."
  ./add-validators.sh
fi

# Check if failed_to_increase_stake.txt has entries
if [ -s failed_to_increase_stake.txt ]; then
  echo "Entries found in failed_to_increase_stake.txt. Running rebalance.sh..."
  ./rebalance.sh
fi

# Check if failed_to_decrease_stake.txt has entries
if [ -s failed_to_decrease_stake.txt ]; then
  echo "Entries found in failed_to_decrease_stake.txt. Running reduce_rebalance.sh..."
  ./reduce_rebalance.sh
fi

  fi
fi
