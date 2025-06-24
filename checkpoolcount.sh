#!/bin/bash

# Count lines excluding the header
entry_count=$(tail -n +2 pool_validators.csv | wc -l)

# Check if the count is zero
if [ "$entry_count" -eq 0 ]; then
    ./replace_delegate.sh
fi
