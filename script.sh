#!/bin/bash

CONFIG_FILE="config.txt"

# Load config file
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Config file '$CONFIG_FILE' not found!"
    exit 1
fi

# Read values from config file
wallets=($(grep "^wallets=" "$CONFIG_FILE" | cut -d '=' -f2 | tr ',' ' '))

# Function to get values from config.txt
get_config_value() {
    grep "^$1=" "$CONFIG_FILE" | cut -d '=' -f2
}

echo "======================================================="
echo "               WELCOME TO THE SMOKE TEST RUNNER"
echo "======================================================="

# Step 1: Ask whether to test wallet-wise or environment-wise
echo "Do you want to test wallet-wise or environment-wise?"
select test_type in "Wallet" "Environment" "Exit"; do
    case $test_type in
        Wallet)
            echo "Selected: Wallet Wise Testing"
            break
            ;;
        Environment)
            echo "Selected: Environment Wise Testing"
            break
            ;;
        Exit)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid selection! Please choose a valid option."
            ;;
    esac
done

# Step 2: If Wallet testing is selected
if [[ "$test_type" == "Wallet" ]]; then
    echo "Select the wallet type:"
    select wallet_name in "${wallets[@]}" "Exit"; do
        case $wallet_name in
            Exit)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Selected Wallet: $wallet_name"
                break
                ;;
        esac
    done

    # Get available issuers for the selected wallet
    issuers_key="${wallet_name}_issuers"
    issuers=($(get_config_value "$issuers_key" | tr ',' ' '))

    echo "Select an issuer type:"
    select ISSUER in "${issuers[@]}" "Exit"; do
        case $ISSUER in
            Exit)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Selected Issuer: $ISSUER"
                break
                ;;
        esac
    done

    # Get available APIs for the selected wallet
    apis_key="${wallet_name}_apis"
    apis=($(get_config_value "$apis_key" | tr ',' ' '))

    echo "Do you want to run for a specific API or full journey?"
    select tags in "${apis[@]}" "Full Journey" "Exit"; do
        case $tags in
            "Full Journey")
                echo "Running Full Journey..."
                TAGS="runall"
                break
                ;;
            Exit)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Selected API: $tags"
                break
                ;;
        esac
    done

    echo "Select the environment:"
    select ENV in "dev" "prod" "Exit"; do
        case $ENV in
            Exit)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Selected Environment: $ENV"
                break
                ;;
        esac
    done

    # Step 3: Get VAULT_ADDR from config.txt based on ENV
    VAULT_ADDR=$(get_config_value "vault_$ENV")

    if [[ -z "$VAULT_ADDR" ]]; then
        echo "Error: Vault address not found for environment '$ENV'"
        exit 1
    fi
    export VAULT_ADDR="$VAULT_ADDR"
    echo "Using Vault Address: $VAULT_ADDR"

    # Step 4: Authenticate with Vault and retrieve token
    echo "Logging into Vault (MFA Required)..."
    VAULT_TOKEN=$(vault login -method=ldap username=$USER | grep 'token ' | awk '{print $2}')

    if [[ -z "$VAULT_TOKEN" ]]; then
        echo "Vault authentication failed!"
        exit 1
    fi

    echo "Vault authentication successful! Token obtained."

    # Step 5: Run Ansible playbook for the selected wallet
    ansible-playbook "${wallet_name}_smoketest_local.yaml" -e "env=$ENV vault_env=$ENV issuer=$ISSUER token=$VAULT_TOKEN tags=$TAGS"

elif [[ "$test_type" == "Environment" ]]; then
    echo "Select the environment to test:"
    select ENV in "dev" "prod" "Exit"; do
        case $ENV in
            Exit)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Selected Environment: $ENV"
                break
                ;;
        esac
    done

    # Step 3: Get VAULT_ADDR from config.txt based on ENV
    VAULT_ADDR=$(get_config_value "vault_$ENV")

    if [[ -z "$VAULT_ADDR" ]]; then
        echo "Error: Vault address not found for environment '$ENV'"
        exit 1
    fi
    export VAULT_ADDR="$VAULT_ADDR"
    echo "Using Vault Address: $VAULT_ADDR"

    # Step 4: Authenticate with Vault and retrieve token
    echo "Logging into Vault (MFA Required)..."
    VAULT_TOKEN=$(vault login -method=ldap username=$USER | grep 'token ' | awk '{print $2}')

    if [[ -z "$VAULT_TOKEN" ]]; then
        echo "Vault authentication failed!"
        exit 1
    fi

    echo "Vault authentication successful! Token obtained."

    # Step 5: Run all Ansible playbooks for the selected environment
    echo "Running tests for all wallets in the $ENV environment..."
    for wallet in "${wallets[@]}"; do
        ansible-playbook "${wallet}_smoketest_local.yaml" -e "env=$ENV token=$VAULT_TOKEN"
    done
fi
