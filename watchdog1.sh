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
    pgrep -f control-daemon.sh > /dev/null || {
        echo "Control daemon not running. Restarting..."
        bash /data/data/com.termux/files/home/control-folder/control-daemon.sh /data/data/com.termux/files/home/control-folder &
    }

    pgrep -x sshd > /dev/null || {
        echo "sshd not running. Restarting..."
        sshd &
    }

    pgrep -x syncthing > /dev/null || {
	echo "syncthing not running. Restarting..."
	syncthing --no-browser &
    }

    pgrep -x crond > /dev/null || {
	echo "crond not running. Restarting..."
	crond &
    }

    pgrep -f watchdog2.sh > /dev/null || {
	echo "Second Watchdog not running. Restarting..."
	bash /data/data/com.termux/files/home/control-folder/watchdog2.sh &
    }

    sleep 5
done
