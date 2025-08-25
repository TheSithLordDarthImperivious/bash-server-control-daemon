#!/bin/bash

# Get script name
SCRIPTNAME="$(basename "$0")"

# Check if the script is already running
if [[ $(pgrep -fc "$SCRIPTNAME") -gt 1 ]]; then
    echo "$SCRIPTNAME is already running. Exiting."
    exit 0
fi

# Watchdog Logic
while true; do
    pgrep -f watchdog1.sh > /dev/null || {
    	echo "First Watchdog not running. Restarting..."
    	bash /data/data/com.termux/files/home/control-folder/watchdog1.sh
    }

    sleep 5
done
