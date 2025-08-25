#!/bin/sh

# $1 is the directory that would contain the emailer script

# Check if argument is not a directory
if [ ! -d "$1" ]; then
    echo "You must specify a valid directory!"
    exit 1
fi

while true; do
	echo "SSHing in and seeing if everything is OK..."
	echo -e "There will be a list of process numbers!\n"
	# Use pgrep to check if processes exist
	ssh -o BatchMode=yes -p 8022 u0_a55@10.0.0.10 "pgrep syncthing && pgrep crond && pgrep -f control-daemon.sh && pgrep -f watchdog1.sh && pgrep -f watchdog2.sh"

	# Store exit code
	EXIT_CODE="$?"
	echo

	# Check error code
	if [ "$EXIT_CODE" -eq 0 ]; then
		echo "Server is consistent! Nothing to do..."
		exit 0
	elif [ "$EXIT_CODE" -eq 255 ]; then
		echo "ERROR: Manual Intervention needed!"
        bash -c "$1/emailer.sh" "$1" "Manual Intervention Needed to Restart Server!" "$(cat <<EOF
<h2>Please Reboot Monitoring Server!</h2>
<p>The watchdog detected that the monitoring server is <strong>not responding</strong> to an SSH request.</p>
<p>This indicates that nothing is running, and the server needs a <strong>forced reboot by power-cycle</strong>.</p>
<p>To restore functionality, power-cycle the monitoring server <strong>as soon as possible</strong>.</p>
EOF
)"		exit 1
	else
		echo "Rebooting server..."
		ssh -o BatchMode=yes -p 8022 u0_a55@10.0.0.10 "su -c reboot"
		echo "Waiting 60 seconds for control server to boot..."
		sleep 60
		echo "Restarting loop..."
	fi
done
