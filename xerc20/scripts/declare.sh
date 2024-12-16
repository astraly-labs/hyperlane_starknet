#!/bin/bash

# Function to declare the contract and extract hashes
declare_contract() {
    local contract_name="$1" # Take the contract name as a parameter
    local profile="$2"
    local fee_token="$3"

    echo "Executing sncast command to declare the contract '$contract_name'..."
  
    # Run the sncast command and capture the output
    output=$(sncast --profile $profile --wait declare \
        --fee-token $fee_token \
        --contract-name "$contract_name")
  
    echo "Command executed successfully."

    # Check if output is not empty
    if [[ -z "$output" ]]; then
      echo "Error: No output received from sncast command."
      echo "Output: $output"  # Show output
      return 1  # Changed from exit to return
    fi

    # Extract class_hash
    class_hash=$(echo "$output" | grep -E "class_hash[:=]" | awk -F '[:=]' '{gsub(/ /, "", $2); print $2}')

    # Validate extraction
    if [[ -z "$class_hash" ]]; then
      echo "Error: class_hash not found in the output."
      echo "Output: $output"  # Show output
      return 1  # Changed from exit to return
    fi
    # Output the extracted hashes
    echo "$contract_name: $class_hash" >> "deployments/$STARKNET_NETWORK/declared-classes.txt"
    echo "Class hash for $contract_name saved to deployments/$STARKNET_NETWORK/declared-classes.txt"
}

if [[ -z "$STARKNET_NETWORK" ]]; then
    echo "Error: STARKNET_NETWORK is not set."
    return 1  # Changed from exit to return
fi
# Determine the file path based on the STARKNET_NETWORK environment variable
output_dir="deployments/$STARKNET_NETWORK"
output_file="$output_dir/declared-classes.txt"

local profile=$PROFILE
if [[ -z "$profile" ]]; then
    profile="default"
fi

local fee_token=$FEE_TOKEN
if [[ -z "$fee_token" ]]; then
    fee_token="strk"
fi

# Create the directory if it doesn't exist
mkdir -p "$output_dir"

# Remove existing declared-classes.txt file if it exists
rm -f "$output_file"

# Call the function with the provided contract name
declare_contract "XERC20Factory" $profile $fee_token
declare_contract "XERC20" $profile $fee_token
declare_contract "XERC20Lockbox" $profile $fee_token