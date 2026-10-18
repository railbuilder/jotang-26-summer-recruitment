#!/usr/bin/env bash

# Task 07: complete this script.
# Usage: ./scripts/analyze.sh FILE

# TODO: validate arguments
# TODO: validate file existence
# TODO: print:
# Total ERROR: <number>
# Top Code: <code>

if [[ $# -ne 1 ]]; then
    echo "Usage: ./scripts/analyze.sh FILE"
    exit 1
fi
FILE="$1"
if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' does not exist."
    exit 1
fi
ERROR_COUNT=$(grep -c "ERROR" "$FILE")
TOP_CODE=$(grep "ERROR" "$FILE" | grep -o "code=[^ ]*" | cut -d'=' -f2 | sort | uniq -c | sort -nr | head -n 1 | awk '{print $2}')

echo "Total ERROR: $ERROR_COUNT"
echo "Top Code: $TOP_CODE"
exit 0
