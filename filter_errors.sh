#!/bin/bash

# Check if filename argument is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <filename>"
    exit 1
fi

# Input filename
filename="$1"

# Function to save error lines
save_error() {
    local line
    while IFS= read -r line || [ -n "$line" ]; do
        if [[ $line == "checking out"* ]]; then
            break
        fi
        echo "$line" >> error.txt
    done
}

# Main script
while IFS= read -r line || [ -n "$line" ]; do
    if [[ $line == "check out program version"* ]]; then
        # Check for java error in next 3 or 4 lines
        for (( i=1; i<=4; i++ )); do
            read nextline || break
            if [[ $nextline == "java"* ]]; then
                # Save lines to error.txt
                echo "$line" > error.txt
                save_error
                break
            fi
        done
    fi
done < "$filename"

echo "Error lines saved in error.txt"