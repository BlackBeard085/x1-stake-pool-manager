#!/bin/bash

# Path to the file
FILE="add_to_pool.txt"

# Check if the file exists
if [ ! -f "$FILE" ]; then
    echo "File $FILE does not exist."
    exit 1
fi

# Check if the file is empty
if [ -s "$FILE" ]; then
    echo -e "\nPlease delegate to validators awaiting pool stake before updating pool validators\n"
else
    # Run the update script if the file is empty
     node import_pool_val.js > /dev/null 2>&1
    ./update_pool_validators.sh
fi
