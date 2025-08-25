#!/usr/bin/env bash

# Copyright (C) "Darth Imperivious" 2025
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# Yes, there were many versions before this was posted on Github. They aren't interesting though.
echo "Server Control Daemon Version 1.3.3 (Encryption Update - Patch 3) Starting..."

echo "This program is licensed under the GNU GPLv3. See the comments for further details."

# Get script name
SCRIPTNAME="$(basename "$0")"
# Get script path
SCRIPTPATH="$1"

# Check if the script is already running
if [[ $(pgrep -fc "$SCRIPTNAME") -gt 1 ]]; then
    echo "$SCRIPTNAME is already running. Exiting."
    exit 0
fi

# Check if argument is not a directory
if [ ! -d "$SCRIPTPATH" ]; then
    echo "You must specify a valid directory!"
    exit 1
fi

# Check if the triggers folder does not exist
if [ ! -d "$SCRIPTPATH/triggers" ]; then
   echo "Triggers folder not found. Creating..."
   # Make the folder
   mkdir "$SCRIPTPATH/triggers"
fi

# Check if the logs folder does not exist
if [ ! -d "$SCRIPTPATH/logs" ]; then
   echo "Logs folder not found. Creating..."
   # Make the folder
   mkdir "$SCRIPTPATH/logs"
fi


# Check if hostnames.txt exists
if [ -f "$SCRIPTPATH/hostnames.txt" ]; then
   # Get name mappings
   NAMEMAPPINGS=$(grep -v "#" "$SCRIPTPATH/hostnames.txt")
fi

function actual_parser() {
        # Get filename
        FILENAME=$(ls "$SCRIPTPATH/triggers" | head -1 | grep -i "_")
        FULLPATH="$SCRIPTPATH/triggers/$FILENAME"
        # Split into command and argument
        CMD="${FILENAME%%_*}"
        ARG="${FILENAME#*_}"

        # Make the original argument empty
        ORIGARG=""
	# Make the port 22 by default
	PORT="22"
        # See if there are mappings
        if [[ "$CMD" == "wake" ]] && [[ "$ARG" != *:* ]]; then
            # Store the original argument
            ORIGARG="$ARG"
            # Find the mapping
            ARG=$(echo "$NAMEMAPPINGS" | grep "^$ARG=" | cut -d'=' -f2 | grep -i ":")
        elif [[ "$CMD" == "ping" ]] && [[ "$ARG" != *.* ]]; then
            ORIGARG="$ARG"
            ARG=$(echo "$NAMEMAPPINGS" | grep "^$ARG=" | cut -d'=' -f2 | grep -i "@" | cut -d "@" -f2)
        elif [[ "$CMD" != "wake" ]] && [[ "$CMD" != "ping" ]] && [[ "$ARG" != *@* ]]; then
            ORIGARG="$ARG"
            ARG=$(echo "$NAMEMAPPINGS" | grep "^$ARG=" | cut -d'=' -f2 | grep -i "@")
        fi

	# See if there is a port (specified by character ",")
	if [[ "$ARG" == *,* ]]; then
		# Define port
		PORT="${ARG#*,}"
		# Also redefine argument (argument will have the port in this case)
		ARG="${ARG%%,*}"
	fi
        # Actually parse, if the arg is not blank
        if [[ "$ARG" != "" ]]; then
            # Generate job id
            JOB_ID=$(date +%Y%m%d-%H%M%S)-$RANDOM
            # Get the date too (logging)
            DATE=$(date "+%Y-%m-%d at %H:%M:%S")
            # Get the file id too
            LOGFILE="$SCRIPTPATH/logs/${CMD}-${ARG}-${JOB_ID}.log"
            case "$CMD" in
              wake)
		COMMAND='wol "$ARG"'
                # Remove the file to show that it's being processed
                rm -f "$FULLPATH"
                # Used to ensure that long commands don't block
                (
                    echo "+=+ Wake On Lan +=+"
                    echo -e "Waking the device with MAC $ARG...\n"
                    # Wake-on-LAN command
                    wol "$ARG"
                    # Get the exitcode
                    EXITCODE=$?
                    echo -e "\n+=+ Wake On Lan Done (Exit Code: $EXITCODE) +=+"
                    # Check the exitcode
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) >"$LOGFILE" 2>&1 & ;;
              # Next blocks are more of the same and follow the same format
              ssh)
                COMMAND=$(< "$FULLPATH")
	        rm -f "$FULLPATH"
                (
                    echo "+=+ SSH +=+"
		    echo "Checking if command contains anything suspicious..."
		    if echo "$COMMAND" | grep -E -i -q \
		       '(^|\s)(rm\s+-[rf]|dd\s+if=|mkfs|:>|truncate\s+-s\s+0|>\/dev\/|cat\s+\/dev\/zero|chown\s+-R\s+\/|chmod\s+[0-7]{3,4}\s+\/|mount\s+-o\s+remount,rw\s+\/|reboot|shutdown|halt|gpg)'; then	                echo "BLOCKED: Execution denied for suspicious command: $COMMAND"
			EXITCODE=1
	       	    else
                        echo -e "Running commands on $ARG...\n"
                        ssh -o BatchMode=yes -p "$PORT" "$ARG" "set -e; $COMMAND"
                        EXITCODE=$?
                    fi
                    echo -e "\n+=+ SSH Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) >"$LOGFILE" 2>&1 & ;;
              update)
                COMMAND="doas /bin/sh -e /usr/local/bin/update-system.sh"
                rm -f "$FULLPATH"
                (
                    echo "+=+ Update +=+"
                    echo -e "Updating $ARG...\n"
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "$COMMAND"
                    EXITCODE=$?
                    echo -e "\n+=+ Update Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) >"$LOGFILE" 2>&1 & ;;
              reboot)
                COMMAND="doas /sbin/reboot"
                rm -f "$FULLPATH"
                (
                    echo "+=+ Reboot +=+"
                    echo "Rebooting $ARG..."
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "$COMMAND"
                    EXITCODE=$?
                    echo "+=+ Reboot Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) >"$LOGFILE" 2>&1 & ;;
              shutdown)
                COMMAND="doas /sbin/halt"
                rm -f "$FULLPATH"
                (
                    echo "+=+ Shutdown +=+"
                    echo "Shutting down $ARG..."
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "$COMMAND"
                    EXITCODE=$?
                    echo "+=+ Shutdown Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
    	      sleep)
                COMMAND="doas /bin/sh -c 'echo mem > /sys/power/state'"
                rm -f "$FULLPATH"
                (
                    echo "+=+ Sleep +=+"
                    echo "Putting $ARG to sleep..."
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "$COMMAND"
                    EXITCODE=$?
                    echo "+=+ Sleep Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
              snapshot)
                COMMAND="doas /bin/sh -e /usr/local/bin/snapshot-all.sh"
                rm -f "$FULLPATH"
                (
                    echo "+=+ BTRFS Snapshot +=+"
                    echo -e "Taking a BTRFS snapshot on $ARG...\n"
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "set -e; $COMMAND"
                    EXITCODE=$?
                    echo -e "\n+=+ BTRFS Snapshot Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
              scrub)
                COMMAND="set -e; doas /usr/local/bin/scrub.sh"
                rm -f "$FULLPATH"
                (
                    echo "+=+ BTRFS Scrub +=+"
                    echo -e "BTRFS Scrubbing $ARG...\n"
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "$COMMAND"
                    EXITCODE=$?
                    echo -e "\n+=+ BTRFS Scrub Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
              uptime)
                COMMAND="set -e; uptime -p"
                rm -f "$FULLPATH"
                (
                    echo "+=+ Uptime +=+"
                    echo -e "Checking uptime on $ARG...\n"
                    ssh -o BatchMode=yes -p "$PORT" "$ARG" "$COMMAND"
                    EXITCODE=$?
                    echo -e "\n+=+ Uptime Check Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
              ping)
		COMMAND='ping -c 10 "$ARG"'
                rm -f "$FULLPATH"
                (
                    echo "+=+ Ping +=+"
                    echo -e "Pinging $ARG...\n"
                    ping -c 10 "$ARG"
                    EXITCODE=$?
                    echo -e "\n+=+ Ping Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
	     # Semi-secure system unlock (useful for remote luks decryption of rootfs).
	     unlock)
		# Definitely don't show the REAL command
		COMMAND='General Encrypted System Unlock'
		# Shove the entire file into a variable (fixes subshell race condition issue), and make it base64 (because bash variables are not designed for binary data)
                FILE_DATA=$(base64 "$FULLPATH")
                rm -f "$FULLPATH"
		(
                    echo "+=+ Unlock +=+"
		    echo "Checking if the file is a GPG encrypted file..."
		    if echo "$FILE_DATA" | base64 -d | file - | grep -i "PGP RSA encrypted session key"; then
	                    echo -e "Check confirms it's a GPG encrypted file, Unlocking $ARG...\n"
			    # Exploit ssh key limitations: on initramfs, execution is restricted, so true will be ignored. In real system, true is not ignored.
	                    echo "$FILE_DATA" | base64 -d | gpg --decrypt | ssh -To BatchMode=yes "$ARG" "true"
	                    EXITCODE=$?
		    else
			    echo -e "\nError: The file is not a GPG file!"
			    EXITCODE=124
		    fi
                    echo -e "\n+=+ Unlock Done (Exit Code: $EXITCODE) +=+"
                    exitcode_checker $EXITCODE $LOGFILE $CMD $ARG $ORIGARG $COMMAND $DATE
                ) > "$LOGFILE" 2>&1 & ;;
              "")
                true ;;
              *)
                rm -f "$FULLPATH"
                echo "Unknown command: $CMD" ;;
            esac
       fi
}

# Exitcode checker which also constructs phrases to use with the mailer command
# Parameters: $1 is the exitcode, $2 is the log file, $3 is the command, $4 is the argument/host, $5 is the original argument (empty if there was no mapping), $6 is the actual command (if applicable), $8 is just the date.
function exitcode_checker() {
    # Only do stuff if the command clearly failed
    if [ ! $1 -eq 0 ]; then
        # Check if there was an original argument
        if [ ! "$ORIGARG" == "" ]; then
            # Set ARG to original argument
            ARG="$5"
        else
            # Set ARG to normal argument
            ARG="$4"
        fi
        # Create subject
        SUBJECT="Action $3 for $ARG failed with error code $1!"
        # Get the error line
        ERROR_LINE=$(grep -niE "error|fail|denied|reset|not[[:space:]]found|disconnect|unreachable" "$2" | head -n 1)
        # Create body
        BODY=$(cat <<EOF

<h2>Command Failed!</h2>
<p><strong>Action:</strong> $3</p>
<p><strong>Host:</strong> $ARG</p>
<p><strong>Date:</strong> $DATE</p>
<p><strong>Command:</strong> <code>$COMMAND</code></p>
<p><strong>Job ID:</strong> $JOB_ID</p>
<p><strong>Exit Code:</strong> $1</p>
<p><strong>Possibly Offending Line:</strong> <code>$ERROR_LINE</code></p>

<p>The full log is attached below.</p>
EOF
)
      # Call the emailer script
      bash "$SCRIPTPATH/emailer.sh" "$SCRIPTPATH" "$SUBJECT" "$BODY" "$LOGFILE"
    # Unlock should always notify me if unlocked no matter what
    elif [ "$3" == "unlock" ] && grep -i "passphrase" "$LOGFILE"; then
	# Call the emailer script
	bash "$SCRIPTPATH/emailer.sh" "$SCRIPTPATH" "NOTICE: $4 Was Unlocked by the Monitoring Server!" "<h2>Machine Unlocked!</h2> <p>The monitoring server has successfully unlocked the encrypted machine $4.</p> <p>If this was expected, please ignore, as this was just a notice.</p> <p>If this was unexcepted, <strong>there are serious issues you need to fix ASAP.</strong></p> <p>The full log is attached below</p>" "$LOGFILE"
    fi
}

while true; do actual_parser "$1"; done
