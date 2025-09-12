#!/bin/zsh
#
# Script Name: extract_name_email.sh
# Purpose    : Extract only Name and College Email columns from a CSV file
#              and convert all names to Title Case.
#
# Usage      : 
#   ./extract_name_email.sh input.csv > output.csv
#
# Example    :
#   Given an input.csv with headers:
#   SL NO,Roll No,Name,Group,Gender,College Email,Class Code,Course,WhatsApp No,Enrolled Year
#   1,12345,john DOE,A,M,john.doe@college.edu,C101,CS,9876543210,2023
#
#   Run:
#   ./extract_name_email.sh input.csv > clean.csv
#
#   Output (clean.csv):
#   Name,College Email
#   John Doe,john.doe@college.edu
#
# Notes      :
#   - Assumes CSV is comma-separated.
#   - Column order must match headers shown above.
#   - $3 = Name column, $6 = College Email column.
#   - Works with multi-word names, ensuring each word is Title Cased.
#   - Redirect output to a new file (e.g., output.csv) to preserve results.

input_file="$1"  # First argument to script is the CSV file name

# awk is used for column extraction and text processing
awk -F',' '
    # For the first row (header), override with "Name,College Email"
    NR==1 { 
        print "Name,College Email"; 
        next 
    } 
    {
        # Extract columns
        name=$3         # Name column
        email=$6        # College Email column

        # Split the name into words based on space
        split(name, parts, " ")

        # Loop through each word in the name
        for (i in parts) {
            # Convert first letter to uppercase, rest to lowercase
            parts[i] = toupper(substr(parts[i],1,1)) tolower(substr(parts[i],2))
        }

        # Rebuild the full name after conversion
        name_out = parts[1]
        for (i=2; i<=length(parts); i++) {
            name_out = name_out " " parts[i]
        }

        # Print processed row with only Name and Email
        print name_out "," email
    }
' "$input_file"

