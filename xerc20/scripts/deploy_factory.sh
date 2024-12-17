# Read class hashes from deployments/declared-classes.txt and store them in a local mapping

deploy_factory() {
    local factory_class_hash="$1"
    local xerc20_class_hash="$2"
    local lockbox_class_hash="$3"
    local profile="$4"
    local fee_token="$5"
    local salt="$6"
    
    echo "Deploying contract factory with class hash '$factory_class_hash'..."
    # Capture the output of the deployment command
    output=$(sncast --profile $profile --wait \
        deploy \
        --fee-token $fee_token \
        --class-hash $factory_class_hash\
        --constructor-calldata $xerc20_class_hash $lockbox_class_hash\
        --salt $SALT\
        --unique
        )
    
    echo "Deployment command executed."

    # Check if output is not empty
    if [[ -z "$output" ]]; then
        echo "Error: No output received from deployment command."
        return 1
    fi

    # Extract transaction_hash and contract_address
    transaction_hash=$(echo "$output" | grep -E "transaction_hash[:=]" | awk -F '[:=]' '{gsub(/ /, "", $2); print $2}')
    contract_address=$(echo "$output" | grep -E "contract_address[:=]" | awk -F '[:=]' '{gsub(/ /, "", $2); print $2}')

    # Validate extraction
    if [[ -z "$transaction_hash" ]]; then
        echo "Error: transaction_hash not found in the output."
        return 1
    fi

    if [[ -z "$contract_address" ]]; then
        echo "Error: contract_address not found in the output."
        return 1
    fi

    # Output the extracted hashes
    echo "Transaction Hash: $transaction_hash"
    echo "Contract Address: $contract_address"

    echo "XERC20Factory: $contract_address" >> "deployments/$STARKNET_NETWORK/deployed-contracts.txt"
    echo "XERC20Factory deployed to $contract_address in tx_hash: $transaction_hash"
}

declare -A class_hashes

if [[ -z "$STARKNET_NETWORK" ]]; then
  echo "Error: STARKNET_NETWORK is not set."
  return 1  # Changed from exit to return
fi

if [[ -z "$SALT" ]]; then
    echo "Error: SALT is not set."
    return 1  # Changed from exit to return
fi
    
local profile=$PROFILE
if [[ -z "$profile" ]]; then
    profile="default"
fi

local fee_token=$FEE_TOKEN
if [[ -z "$fee_token" ]]; then
    fee_token="strk"
fi

input_file="deployments/$STARKNET_NETWORK/declared-classes.txt"

if [[ -f "$input_file" ]]; then
    while IFS= read -r line; do
        # Extract the class name and hash
        class_name=$(echo "$line" | awk -F ': ' '{print $1}')  # Remove trailing colon and whitespace
        class_hash=$(echo "$line" | awk -F ': ' '{print $2}')   # Remove leading/trailing whitespace
        class_hashes[$class_name]=$class_hash
    done < "$input_file"
else
    echo "Input file not found: $input_file"
    return 1
fi

deploy_factory \
    "${class_hashes[XERC20Factory]}" \
    "${class_hashes[XERC20]}" \
    "${class_hashes[XERC20Lockbox]}" \
    $profile \
    $fee_token \
    $SALT
