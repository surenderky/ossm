#!/bin/bash

# Usage: ./extract_fail_line.sh path/to/file.xml

FILE="$1"

if [[ -z "$FILE" || ! -f "$FILE" ]]; then
  echo "Usage: $0 path/to/xmlfile"
  exit 1
fi

# Extract all <failure> blocks, decode XML entities, and print lines ending with '--- FAIL:'
grep -oP '<failure[^>]*>.*?</failure>' "$FILE" | while read -r failure; do
  # Extract content between tags and decode entities
  content=$(echo "$failure" | sed -e 's/^<failure[^>]*>//' -e 's/<\/failure>$//' \
                                  -e 's/&#xA;/\n/g' -e 's/&#x9;/\t/g' \
                                  -e 's/&#39;/'"'"'/g' -e 's/&quot;/"/g' \
                                  -e 's/&amp;/\&/g' -e 's/&lt;/</g' -e 's/&gt;/>/g')
  
  # Find the last line that starts with --- FAIL:
  echo "$content" | grep "^--- FAIL:" | tail -n1
done

