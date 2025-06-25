#!/bin/bash
# Count non-empty lines excluding the header
entry_count=$(tail -n +2 pool_validators.csv | grep -v '^$' | wc -l)

# Check if the count is zero
if [ "$entry_count" -eq 0 ]; then
    ./replace_delegate.sh 2>/dev/null
fi
