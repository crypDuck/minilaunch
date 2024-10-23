#!/bin/bash

# ============================================================================
# MiniLaunch - Ethereum Gas Price Monitor and Transaction Launcher
# ============================================================================
#
# Description:
#   This script is intended for NodeSet Constellation node operators. It
#   monitors Ethereum gas prices and launches minipool creates when the gas price
#   falls below a specified threshold, which can be specified to increase over time.
#   It also checks the contract's ETH balance before executing transactions.
#   This script tries to help avoid FOMO and minimize gas costs by waiting for
#   low gas conditions, rather than trying to compete for deposits as quickly as possible.
#
# Disclaimer:
#   This script is provided as-is, without any guarantees or warranties of any
#   kind. By using this script, you acknowledge that you do so at your own risk.
#   The authors and contributors of this script are not responsible for any
#   potential losses or damages that may occur from its use.
#
# Usage:
#   ./minilaunch.sh [OPTIONS]
#
# Options:
#   -h, --help       Show this help message and exit
#   -r, --gasRampTime Target gas ramp time in hours. Default: $GAS_RAMP_TIME
#   -s, --sleepTime  Time between attempts in seconds (default: 5)
#   -f, --startGas   Starting gas limit (default: 5.1)
#   -e, --endGas     Ending gas limit (default: none)
#   -i, --prioFee    Priority fee (default: 0.08)
#   --dry-run        Run in dry-run mode (no transactions will be executed)
#   --never-exit     Keep running indefinitely, even after successful minipool creation
#
# Requirements:
#   - curl
#   - jq
#   - bc
#   - hyperdrive (custom Ethereum transaction tool)
#
# Author: crypDuck
# Date: 2024-10-23
# Version: 0.15
# ============================================================================

# Load default environment variables
if [[ -f .default.env ]]; then
    source .default.env
else
    echo "Error: .default.env file not found." >&2
    exit 1
fi

# Load user-defined environment variables (if exists)
if [[ -f .env ]]; then
    source .env
fi

# Check if API_KEY is set
if [[ -z "$API_KEY" ]]; then
    echo "Error: API_KEY is not set. Please create a .env file with your API_KEY." >&2
    exit 1
fi

DRY_RUN=false

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  -h, --help       Show this help message and exit"
    echo "  -r, --gasRampTime Target gas ramp time in hours. Default: $GAS_RAMP_TIME"
    echo "  -s, --sleepTime  Time between attempts in seconds. Default: $SLEEP_TIME"
    echo "  -f, --startGas   Starting gas limit. Default: $START_GAS"
    echo "  -e, --endGas     Ending gas limit. Default: ${END_GAS:-<none>}."
    echo "  -i, --prioFee    Priority fee. Default: $PRIO_FEE"
    echo "  --dry-run        Run in dry-run mode (no transactions will be executed)"
    echo "  --never-exit     Keep running indefinitely, even after successful minipool creation"
}

# Function to sanitize and validate numeric input
sanitize_numeric_input() {
    local input="$1"
    local default="$2"
    local param_name="$3"

    # Remove all non-digit and non-period characters
    local sanitized_input="${input//[^0-9.]/}"

    # Check if the sanitized input is either an integer or a float
    if [[ $sanitized_input =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "$sanitized_input"
    else
        echo "Invalid parameter $param_name, using default of $default" >&2
        echo "$default"
    fi
}

# Function to fetch the current gas price
get_gas_price() {
    local gas_price_hex
    local gas_price_dec
    local gas_price_gwei

    gas_price_hex=$(curl -s "$API_URL/api?module=proxy&action=eth_gasPrice&apikey=$API_KEY" | jq -r '.result')
    gas_price_dec=$((gas_price_hex))
    gas_price_gwei=$(echo "scale=2; $gas_price_dec / 1000000000" | bc)
    echo "$gas_price_gwei"
}

# Function to get ETH balance for a contract address from Etherscan API
get_pool_eth_balance() {
    local api_endpoint="/api?module=account&action=balance&address=$OPR_DIST_CONTRACT_ADDR&tag=latest&apikey=$API_KEY"
    local response
    local balance
    local ether_balance

    response=$(curl -s "$API_URL$api_endpoint")

    if [[ $response =~ "1" ]]; then
        balance=$(echo "$response" | jq -r '.result')
        ether_balance=$(echo "scale=9; $balance / 1000000000000000000" | bc)
        echo "$ether_balance"
    else
        echo "-1"
    fi
}

has_pool_sufficient_liquidity() {
    local hex_bond=$(printf "%064x" $BOND_SIZE)
    
    local url="$API_URL"
    url+="/api"
    url+="?module=proxy"
    url+="&action=eth_call"
    url+="&to=$SUPERNODE_ACC_ADDR"
    url+="&data=0xbb095456000000000000000000000000000000000000000000000000$hex_bond"
    url+="&tag=latest"
    url+="&apikey=$API_KEY"

    local result=$(curl -s -G "$url")

    if [[ $result == *"0x0000000000000000000000000000000000000000000000000000000000000001"* ]]; then
        return 0  # true in bash
    else
        return 1  # false in bash
    fi
}

# Function to read an unmarked salt from the salts.txt file
read_salt() {
    if [[ ! -f "$SALT_FILE" ]]; then
        echo ""
        return
    fi

    grep -v '^#' "$SALT_FILE" | head -n 1
}

# Function to mark a salt as used in the salts.txt file
mark_salt() {
    local salt="$1"

    if [[ ! -f "$SALT_FILE" ]]; then
        return
    fi

    sed -i -e "s/^$salt/# $salt/" "$SALT_FILE"
    echo "Marked salt $salt as used in $SALT_FILE"
}

# Function to send a notification to a Discord webhook
notify_discord() {
    # send notification if DISCORD_WEBHOOK_URL is set
    if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
        echo "Sending Discord notification..."
        local message="$1"
        local url="$DISCORD_WEBHOOK_URL"
        local payload='{"content":"'"$message"'"}'
        local http_status=$(curl -s -o /dev/null -w "%{http_code}" -H "Content-Type: application/json" -d "$payload" "$url")
        if [[ $http_status -eq 204 ]]; then
            echo "Discord notification sent successfully."
        else
            echo "Failed to send Discord notification. HTTP status code: $http_status"
        fi
    fi
    # if DISCORD_WEBHOOK_URL is not set, do nothing
}

# Function to print a message and send it as notification
print_and_notify() {
    local message="$1"
    local additional_info="$2"
    echo "$message"
    if [ -n "$additional_info" ]; then
        notify_discord "${message}\n${additional_info}"
    else
        notify_discord "$message"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help|help)
            show_help
            exit 0
            ;;
        -r|--gasRampTime)
            GAS_RAMP_TIME=$(sanitize_numeric_input "$2" "$GAS_RAMP_TIME" "--gasRampTime")
            shift
            ;;
        -f|--startGas)
            START_GAS=$(sanitize_numeric_input "$2" "$START_GAS" "--startGas")
            shift
            ;;
        -e|--endGas)
            END_GAS=$(sanitize_numeric_input "$2" "$END_GAS" "--endGas")
            shift
            ;;
        -i|--prioFee)
            PRIO_FEE=$(sanitize_numeric_input "$2" "$PRIO_FEE" "--prioFee")
            shift
            ;;
        -s|--sleepTime)
            SLEEP_TIME=$(sanitize_numeric_input "$2" "$SLEEP_TIME" "--sleepTime")
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --never-exit)
            NEVER_EXIT=1
            ;;
        *)
            echo "Unknown parameter passed: $1" >&2
            show_help
            exit 1
            ;;
    esac
    shift
done

# Print dry-run status
if [ "$DRY_RUN" = true ]; then
    echo "Running in DRY RUN mode. No transactions will be executed."
else
    echo "Running in LIVE mode. Transactions will be executed when conditions are met."
fi

# Convert gas ramp time to seconds
GAS_RAMP_TIME_SECONDS=$((GAS_RAMP_TIME * 3600))

# Capture start time
START_TIME=$(date +%s)

# Error checks
echo "startGas: $START_GAS, endGas: $END_GAS"
if [ -n "$END_GAS" ] && [ $(echo "$END_GAS < $START_GAS" | bc -l) -eq 1 ]; then
    echo "Error: endGas must be greater than or equal to startGas." >&2
    exit 1
fi

# Read salt
SALT="$(read_salt)"
if [ -z "$SALT" ]; then
    echo "Not using salt"
else
    echo "Using salt $SALT"
fi

GAS_LIMIT=$START_GAS

# Main loop
while true; do
    GAS_PRICE=$(get_gas_price)

    # Calculate adjusted gas price and round up to 2 decimal places
    ADJUSTED_GAS_PRICE=$(echo "scale=2; ($GAS_PRICE * $GAS_MARGIN + 0.005) / 1" | bc)

    # Calculate percentage over GAS_LIMIT, allowing for more than 100%; subtract 15%, i.e., only adjust sleep if gas is more than 25% higher
    PERCENT_OVER_LIMIT=$(echo "scale=2; ($ADJUSTED_GAS_PRICE / $GAS_LIMIT - 1) * 100 - 15" | bc -l)

    # Check if PERCENT_OVER_LIMIT is negative, set to 0 if it is
    if (( $(echo "$PERCENT_OVER_LIMIT < 0" | bc -l) )); then
        PERCENT_OVER_LIMIT=0
    fi

    # Calculate additional sleep time
    ADD_SLEEP=$PERCENT_OVER_LIMIT

    # Calculate SLEEP_NEXT as the sum of SLEEP_TIME and additional time, ensuring it's at least SLEEP_TIME
    SLEEP_NEXT=$(echo "$SLEEP_TIME + $ADD_SLEEP" | bc -l | awk '{printf "%.0f", $1}')
    # Cap at 5 minutes (300 seconds)
    if (( $(echo "$SLEEP_NEXT > 300" | bc -l) )); then
        SLEEP_NEXT=300
    fi

    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    FRACTION=$(echo "scale=5; $ELAPSED / $GAS_RAMP_TIME_SECONDS" | bc)

    if [ -n "$END_GAS" ]; then
        # If we've passed the target time, use END_GAS
        if [ $ELAPSED -ge $GAS_RAMP_TIME_SECONDS ]; then
            GAS_LIMIT=$END_GAS
        else
            # Calculate GAS_LIMIT based on elapsed time
            GAS_LIMIT=$(echo "scale=2; $START_GAS + ($END_GAS - $START_GAS) * $FRACTION" | bc)
        fi
    fi

    if (( $(echo "$ADJUSTED_GAS_PRICE <= $GAS_LIMIT" | bc -l) )); then
        POOL_ETH=$(get_pool_eth_balance)
        # Check if balance is a valid number (not an error code like -1) and >= $MIN_POOL_SIZE
        if (( $(echo "$POOL_ETH >= $MIN_POOL_SIZE" | bc -l) )) && [[ ! "$POOL_ETH" =~ ^- ]] && has_pool_sufficient_liquidity; then
            print_and_notify "$(date "+%Y-%m-%d %H:%M:%S") Adjusted gas price ($ADJUSTED_GAS_PRICE) is less than or equal to $GAS_LIMIT gwei and there is $POOL_ETH ETH in the pool. Pool has sufficient liquidity. Executing command..." \
                "Gas and liquidity conditions are favorable."
            COMMAND="hyperdrive -f $ADJUSTED_GAS_PRICE -i $PRIO_FEE cs m c -y${SALT:+ -l }$SALT"
            echo "Trying: $COMMAND"
            if [ "$DRY_RUN" = true ]; then
                print_and_notify "[DRY RUN] Command would be executed otherwise." "Command: $COMMAND"
                exit 0
            fi
            # Execute the command and capture its output
            OUTPUT=$($COMMAND | sed '/^$/d')
            echo "$OUTPUT"

            if [[ "$OUTPUT" =~ "Minipool created successfully" ]]; then
                print_and_notify "Minipool created successfully." "Output: $OUTPUT"
                mark_salt "$SALT"
                SALT=$(read_salt)
                echo "Going to sleep for 12 hours before continuing..."
                sleep 43200  # 12 hours in seconds
                START_TIME=$(date +%s)
            elif [[ "$OUTPUT" =~ "Cannot create" ]]; then
                # Conditions not met, continue waiting
                :
            else
                print_and_notify "Unexpected output. Minipool creation may have failed. Exiting." "Output: $OUTPUT"
                exit 1
            fi
        else
            # Handle cases where balance is less than MIN_POOL_SIZE or there was an error
            if [[ "$POOL_ETH" == "-1" ]]; then
                print_and_notify "$(date "+%Y-%m-%d %H:%M:%S") Failed to retrieve pool balance. Check your internet connection or API key."
            elif ! has_pool_sufficient_liquidity; then
                print_and_notify "$(date "+%Y-%m-%d %H:%M:%S") The pool does not have sufficient liquidity"
            else
                print_and_notify "$(date "+%Y-%m-%d %H:%M:%S") The pool balance is $POOL_ETH ETH, which is less than $MIN_POOL_SIZE ETH"
            fi
        fi
        sleep "$SLEEP_NEXT"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S") Adjusted gas price is $ADJUSTED_GAS_PRICE gwei, which is higher than $GAS_LIMIT. Waiting for $SLEEP_NEXT seconds..."
        sleep "$SLEEP_NEXT"
    fi
done
