#!/bin/bash

# Function to check if a string starts with "java" followed by any character
startsWithJava() {
    [[ $1 =~ ^java.+ ]]
}

# Function to check if a string starts with "init local repository"
startsWithInitLocalRepository() {
    [[ $1 == "init local repository"* ]]
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

# Input file
input_file="$1"

# Output file for errors
error_file="error.txt"

# Remove any existing error file
rm -f "$error_file"

# Process input file
while IFS= read -r line; do
    if startsWithJava "$line"; then
        # Store current line
        java_line="$line"

        # Store three lines above
        for (( i = 1; i <= 3; i++ )); do
            if IFS= read -r prev_line; then
                java_line="$prev_line"$'\n'"$java_line"
            else
                echo "Error: Reached the beginning of the file before finding the required context." >> "$error_file"
                break
            fi
        done

        # Store lines until "init local repository" is found
        while IFS= read -r next_line; do
            if startsWithInitLocalRepository "$next_line"; then
                echo "$java_line" >> "$error_file"
                break
            fi
            java_line="$java_line"$'\n'"$next_line"
        done
    fi
done < "$input_file"

# Remove temporary file
rm -f "$temp_file"