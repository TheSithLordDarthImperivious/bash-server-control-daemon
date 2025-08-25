#!/bin/bash

# Copyright (C) "Darth Imperivious" 2025
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# Arguments list
# $1 is the folder that contains emails.txt, $2 is the subject, $3 is the body. $4 is the attachment (OPTIONAL).

# Check if argument is not a directory and if it contains emails.txt
if [ ! -f "$1/emails.txt" ]; then
    echo "You must specify a valid directory, and it must contain emails.txt!"
    exit 1
fi

# Check if either arguments 2 or 3 are null
if [ "$2" == "" ] || [ "$3" == "" ]; then
   echo "Arguments 2 and 3 must not be blank!"
   exit 1
fi

# Get to and from
TO=$(grep "to" "$1/emails.txt" | cut -d' ' -f2)
FROM=$(grep "from" "$1/emails.txt" | cut -d' ' -f2)

# Define signature
SIG="<br><br>--<br>Sent by the Automated Email Alert System (v1.0.0).<br>This system will not respond to replies."

if [ -n "$4" ] && [ -f "$4" ]; then
    # With attachment
    BOUNDARY="=====multipart_boundary_$(date +%s)==="
    {
        echo "From: Automated Server Administration System <$FROM>"
        echo "To: $TO"
        echo "Subject: $2"
        echo "MIME-Version: 1.0"
        echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\""
        echo
        echo "--$BOUNDARY"
        echo "Content-Type: text/html; charset=UTF-8"
        echo "Content-Transfer-Encoding: 7bit"
        echo
        echo "$3$SIG"
        echo
        echo "--$BOUNDARY"
        echo "Content-Type: text/plain; name=\"$(basename "$4")\""
        echo "Content-Disposition: attachment; filename=\"$(basename "$4")\""
        echo "Content-Transfer-Encoding: base64"
        echo
        base64 "$4"
        echo "--$BOUNDARY--"
    } | msmtp --from=default "$TO"
else
    {
        echo "From: Automated Server Administration System <$FROM>"
        echo "To: $TO"
        echo "Subject: $2"
        echo "Content-Type: text/html"
        echo ""
        echo "$3$SIG"
    } | msmtp --from=default "$TO"
fi
