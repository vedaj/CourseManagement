#!/bin/zsh
#
# Script Name : extract_name_email.sh
# Purpose     : Extract only Name and College Email columns from a CSV file,
#               convert names to Title Case (handling hyphens and apostrophes),
#               and emails to lowercase.
#
# Usage       :
#   ./extract_name_email.sh input.csv output.csv
#
# Example     :
#   ./extract_name_email.sh StudentListOriginal.csv NameEmail.csv
#
# Notes       :
#   - Assumes CSV is comma-separated.
#   - $3 = Name column, $6 = College Email column.
#   - Output will contain header: "Name,College Email".
#

input_file="$1"
output_file="$2"

if [[ -z "$input_file" || -z "$output_file" ]]; then
  echo "Usage: $0 input.csv output.csv"
  exit 1
fi

awk -F',' 'BEGIN{OFS=","}
# Function: TitleCase a word, including parts split by "-" and "'"
function toTitleCase(word,   n, parts, i, j, subpart, result) {
    n = split(word, parts, /[-'']/)  # split on - or '
    result = word
    j = 1
    for (i = 1; i <= n; i++) {
        if (length(parts[i]) > 0) {
            subpart = toupper(substr(parts[i],1,1)) tolower(substr(parts[i],2))
            # replace only the next occurrence of the part
            match(result, parts[i])
            if (RSTART > 0) {
                result = substr(result,1,RSTART-1) subpart substr(result,RSTART+RLENGTH)
            }
        }
    }
    return result
}

NR==1 {
    print "Name","College Email"
    next
}
{
    name=$3
    email=tolower($6)

    split(name, words, " ")
    for (i in words) {
        words[i] = toTitleCase(words[i])
    }

    name_out = words[1]
    for (i=2; i<=length(words); i++) {
        name_out = name_out " " words[i]
    }

    print name_out, email
}' "$input_file" > "$output_file"

