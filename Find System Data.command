#!/bin/bash

# Change to the directory where this script is located
cd "$(dirname "$0")"

# Run the system data finder script
python3 find_system_data.py

# Keep the terminal window open so user can see the results
echo ""
echo "Press any key to close this window..."
read -n 1 -s

