#!/bin/bash

# Change to the directory where this script is located
cd "$(dirname "$0")"

# Run the unified Mac cleaner script
./mac_cleaner.sh

# Keep the terminal window open so user can see the results
echo ""
echo "Press any key to close this window..."
read -n 1 -s

