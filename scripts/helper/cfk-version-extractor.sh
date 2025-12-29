#!/bin/bash

# This script is going to scrape our public documentation for the CFK Operator Version to Chart Mapping and store it in a json file.

if [ -z "$BASE_DIR" ]; then
    echo "Please export BASE_DIR=\$(pwd)"
    exit 1
fi

REQUIRED_PKG="curl jq"
URL="https://docs.confluent.io/operator/current/co-plan.html#co-long-image-tags"
GEN_DIR="$BASE_DIR/generated/cfk_version"
TEMP_JSON="$GEN_DIR/version_mapping.json.tmp"
VERSION_JSON="$GEN_DIR/version_mapping.json"

# check for prerequisites
for PKG in $REQUIRED_PKG; do
    if [ -z "$(which ${PKG})" ]; then
        printf "REQUIRED: %s" "${PKG}"
        printf "\nPlease install %s" "${PKG}"
        printf "\nUsing Brew:"
        printf "\n\tbrew install %s" "${PKG}"
        exit 1
    fi
done

printf "Extracting Version mapping from %s\n" "$URL"
echo "--------------------------------------------------------"

mkdir -p "$GEN_DIR"
cp "$BASE_DIR/configs/cfk/version_mapping.json" "$VERSION_JSON"

PAGE=$(curl -s "$URL" | \
  tr -d '\n\r' | \
  sed -E 's/^.*CRD Chart Version(.*)To get the list of your current CFK CRDs and the versions,.*/\1/' | \
  sed -E 's/<\/thead>/\t/g' | \
  sed -E 's/<tbody>/\n/g' | \
  sed -E 's/<\/td>/\t/g' | \
  sed -E 's/<\/tr>/\n/g' | \
  awk -F'\t' '
    /^[ \t]*<tr/ { # Only process lines that start with <tr> (the actual rows)
      
      # Extract the first two columns (Operator Version and Image Tag)
      # $2 is the first <td> content, $3 is the second.
      # We strip all remaining HTML tags (like <p> or <td>) from the fields.
      operator_version = $3
      image_tag = $2
      
      # Clean up remaining HTML/whitespace from the extracted fields
      gsub(/<[^>]*>/, "", operator_version)
      gsub(/<[^>]*>/, "", image_tag)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", operator_version)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", image_tag)
      
      # Ensure data is valid before printing
      if (operator_version != "" && image_tag != "") {
        #printf "CFK Operator Version: %s | CFK Image Tag: %s\n", operator_version, image_tag
        printf "%s:%s\n", operator_version, image_tag
      }
    }
')

if [ -z "$PAGE" ]; then
    printf "Scrapping failed, exiting...\n"
    exit 1
fi

while IFS= read -r line; do
   cp $VERSION_JSON $TEMP_JSON 
    # Check if the line is not empty before processing
    if [[ -n "$line" ]]; then
        # Process the line here. Example: print the line and its length.
        line_length=${#line}
        #echo "[PROCESSED] Line: \"$line\" (Length: $line_length)"
        CFK_VERSION=$(echo $line | awk -F ':' '{ print $1 }')
        IMAGE_VERSION=$(echo $line | awk -F ':' '{ print $2 }')
        jq --arg KEY "$CFK_VERSION" --arg VALUE "$IMAGE_VERSION" '.[$KEY] = $VALUE' "$TEMP_JSON" > "$VERSION_JSON"
    fi
    
done <<< "$PAGE"

# compare hash with offline
if [ "$(md5sum $VERSION_JSON | awk '{print $1}')" == "$(md5sum $BASE_DIR/configs/cfk/version_mapping.json | awk '{print $1}')" ]; then
    printf "Extracted version matches local version\n"
else
    printf "Extracted version does not match local version\nConsider replacing local version with extracted version\n"
    # display contents
    cat "$GEN_DIR/version_mapping.json"
fi
echo "--------------------------------------------------------"
echo "Scraping Complete."
