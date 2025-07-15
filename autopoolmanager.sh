#!/bin/bash

#export solana node jq and cargo PATH
export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
export PATH="$HOME/.nvm/versions/node/v20.0.0/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

LOG_FILE="auto_pool_manager.log"
CONFIG_FILE="config.json"
AMEND_FILE="redistribute.json"

# Path to the JSON file containing the keypair
POOL_KEYPAIRS_FILE="pool_keypairs.json"
# Extract the stakePoolKeypair from the JSON file
stakePoolKeypair=$(jq -r '.stakePoolKeypair' "$POOL_KEYPAIRS_FILE")
# Check if jq was able to extract the keypair
if [ -z "$stakePoolKeypair" ] || [ "$stakePoolKeypair" == "null" ]; then
  echo "Error: Could not find 'stakePoolKeypair' in $POOL_KEYPAIRS_FILE"
  exit 1
fi

# Extract the delegate amount from config.json
AMOUNT_FOR_EACH_VALIDATOR=$(jq -r '.amendedAmount' "$AMEND_FILE")
if [ -z "$AMOUNT_FOR_EACH_VALIDATOR" ] || [ "$AMOUNT_FOR_EACH_VALIDATOR" == "null" ]; then
  echo "Error: Could not find 'amendedAmount' in $AMEND_FILE"
  exit 1
fi

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

    #Update Pool
    log "Updating Pool"
    ./update.sh 2>&1 | tee -a "$LOG_FILE"

    # When epoch changes, check all failure logs/files
    FAILED_REMOVE_ENTRIES=$(test -s failed_to_remove.log && echo "yes" || echo "no")
    FAILED_ADD_ENTRIES=$(test -s failed_to_add.log && echo "yes" || echo "no")
    FAILED_INCREASE_STAKE_ENTRIES=$(test -s failed_to_increase_stake.txt && echo "yes" || echo "no")
    FAILED_DECREASE_STAKE_ENTRIES=$(test -s failed_to_decrease_stake.txt && echo "yes" || echo "no")
    
    # If any failure logs/files have entries, handle all then exit
    if [ "$FAILED_REMOVE_ENTRIES" = "yes" ] || [ "$FAILED_ADD_ENTRIES" = "yes" ] || [ "$FAILED_INCREASE_STAKE_ENTRIES" = "yes" ] || [ "$FAILED_DECREASE_STAKE_ENTRIES" = "yes" ]; then
      if [ "$FAILED_REMOVE_ENTRIES" = "yes" ]; then
        log "Entries found in failed_to_remove.log. Running remove-validators.sh..."
      
        mv failed_to_remove.log resolve_failed_to_remove.log
        ./remove-validators.sh "$stakePoolKeypair" resolve_failed_to_remove.log 2>&1 | tee -a "$LOG_FILE"
      fi
      if [ "$FAILED_ADD_ENTRIES" = "yes" ]; then
        log "Entries found in failed_to_add.log. Running add-validators.sh..."
     
        mv failed_to_add.log resolve_failed_to_add.log
        ./add-validators.sh "$stakePoolKeypair" resolve_failed_to_add.log 2>&1 | tee -a "$LOG_FILE"
        sleep 5
      fi
      if [ "$FAILED_INCREASE_STAKE_ENTRIES" = "yes" ]; then
        log "Entries found in failed_to_increase_stake.txt. Running rebalance.sh..."
        mv failed_to_increase_stake.txt resolve_failed_to_increase_stake.txt
        ./rebalance.sh "$stakePoolKeypair" resolve_failed_to_increase_stake.txt "$AMOUNT_FOR_EACH_VALIDATOR" 2>&1 | tee -a "$LOG_FILE"
      fi
      if [ "$FAILED_DECREASE_STAKE_ENTRIES" = "yes" ]; then
        log "Entries found in failed_to_decrease_stake.txt. Running reduce_rebalance.sh..."
        mv failed_to_decrease_stake.txt resolve_failed_to_decrease_stake.txt
        ./reduce_rebalance.sh "$stakePoolKeypair" resolve_failed_to_decrease_stake.txt "$AMOUNT_FOR_EACH_VALIDATOR" 2>&1 | tee -a "$LOG_FILE"
      fi
      exit 0
    else
      log "No failure entries detected. Proceeding with epoch update and pool management."
    fi
    
    # No failure logs/files have entries, proceed to update epoch and run pool procedures
    # Update epoch in config.json
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
    
    #Check if staking new validators was successful
    FAILED_INCREASE_STAKE_ENTRIES=$(test -s failed_to_increase_stake.txt && echo "yes" || echo "no")
      if [ "$FAILED_INCREASE_STAKE_ENTRIES" = "yes" ]; then
        log "Entries found in failed_to_increase_stake.txt. Running rebalance.sh..."
        mv failed_to_increase_stake.txt add_to_pool.txt
        ./stake_validators.sh  2>&1 | tee -a "$LOG_FILE"
        exit 0
      else
        log "All new validators staked successfully, continuing to update validators"
      fi
    log "Updating pool with top performing validators"
    node import_pool_val.js > /dev/null 2>&1
    ./update_pool_validators.sh 2>&1 | tee -a "$LOG_FILE"
    
    sleep 5
    
    log "Checking possible stake redistribution options"
    node autocheckreserve.js 2>&1 | tee -a "$LOG_FILE"
    
    log "Auto Pool manager complete"
  else
    # Epoch is already up-to-date, just continue with normal operations
    log "Epoch in config.json is already up-to-date: $EXISTING_EPOCH"

    #Update Pool
    log "Updating Pool"
    ./update.sh 2>&1 | tee -a "$LOG_FILE"

    log "Checking failures adding/removing validators and increasing/decreasing validator stake"

    # Check if failed_to_remove.log has entries
    if [ -s failed_to_remove.log ]; then
      log "Entries found in failed_to_remove.log. Running remove-validators.sh..."
        mv failed_to_remove.log resolve_failed_to_remove.log
        ./remove-validators.sh "$stakePoolKeypair" resolve_failed_to_remove.log 2>&1 | tee -a "$LOG_FILE"
    else
      log "No entries in failed_to_remove.log."
    fi

    # Check if failed_to_add.log has entries
    if [ -s failed_to_add.log ]; then
      log "Entries found in failed_to_add.log. Running add-validators.sh..."
        mv failed_to_add.log resolve_failed_to_add.log
        ./add-validators.sh "$stakePoolKeypair" resolve_failed_to_add.log 2>&1 | tee -a "$LOG_FILE"
      sleep 5
    else
      log "No entries in failed_to_add.log."
    fi

    # Check if failed_to_increase_stake.txt has entries
    if [ -s failed_to_increase_stake.txt ]; then
      log "Entries found in failed_to_increase_stake.txt. Running rebalance.sh..."
      mv failed_to_increase_stake.txt resolve_failed_to_increase_stake.txt
      ./rebalance.sh "$stakePoolKeypair" resolve_failed_to_increase_stake.txt "$AMOUNT_FOR_EACH_VALIDATOR" 2>&1 | tee -a "$LOG_FILE"
    else
       log "No entries in failed_to_increase.log."
    fi

    # Check if failed_to_decrease_stake.txt has entries
    if [ -s failed_to_decrease_stake.txt ]; then
      log "Entries found in failed_to_decrease_stake.txt. Running reduce_rebalance.sh..."
      mv failed_to_decrease_stake.txt resolve_failed_to_decrease_stake.txt
      ./reduce_rebalance.sh "$stakePoolKeypair" resolve_failed_to_decrease_stake.txt "$AMOUNT_FOR_EACH_VALIDATOR" 2>&1 | tee -a "$LOG_FILE"
    else
       log "No entries in failed_to_decrease.log."
    fi
  fi
fi
