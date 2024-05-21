#!/bin/bash
set -e

# Define the path to the inf_output.json
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
JSON_FILE_PATH="${DIR}/../inf_output.json" # Adjust path as necessary

# Read and export variables from JSON
echo "Setting environment variables from JSON..."
while IFS="=" read -r key value; do
  # Using printf to handle cases where value may have special characters
  printf -v esc_value "%q" "$value"
  export "$key=$esc_value"
done < <(jq -r '. | to_entries | .[] | "\(.key | ascii_upcase | gsub("[.-]"; "_"))=\(.value.value)"' "$JSON_FILE_PATH")

# Directory containing Helm charts
CHARTS_DIR="$DIR/../charts"

# Update values.yaml in each chart directory
if [ -d "$CHARTS_DIR" ]; then
    for chart_dir in "$CHARTS_DIR"/*; do
        if [ -d "$chart_dir" ]; then 
            echo "Processing chart directory: $chart_dir"
            template_file="$chart_dir/values.yaml.template"
            values_file="$chart_dir/values.yaml"
            if [ -f "$template_file" ]; then
                echo "Updating $values_file from template..."
                envsubst < "$template_file" > "$values_file"
            else
                echo "Template file not found in $chart_dir"
            fi
        fi
    done
else
    echo "Charts directory not found: $CHARTS_DIR"
fi
