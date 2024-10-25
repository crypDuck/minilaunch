# minilaunch

minilaunch is a shell script that helps automate the minipool creation process for NodeSet Constellation pools. It monitors Ethereum gas prices and launches minipool creates when the gas price falls below a specified threshold, which can be configured to increase over time. The script also checks the contract's ETH balance before executing transactions.

This script is designed to help avoid FOMO (Fear of Missing Out) and minimize gas costs by waiting for low gas conditions, rather than trying to compete for deposits as quickly as possible. It's particularly useful for node operators who want to optimize their minipool creation process.

## Disclaimer

This script is provided as-is, without any guarantees or warranties of any kind. By using this script, you acknowledge that you do so at your own risk. The authors and contributors of this script are not responsible for any potential losses or damages that may occur from its use.

## Features

- Monitors Ethereum gas prices
- Executes minipool creation when gas prices are favorable
- Adjustable gas price threshold that can increase over time
- Checks contract ETH balance before executing transactions
- Configurable via environment variables
- Optional use of a list of salts for minipool creation
  - Allows for unique identification of minipools
  - Supports multiple minipool creations with different salts
- Dry-run mode for testing without executing actual transactions

## Installation and Setup

1. **Clone the repository:**
   ```
   git clone https://github.com/crypDuck/minilaunch.git
   cd minilaunch
   ```

2. **Make the script executable:**
   ```
   chmod +x minilaunch.sh
   ```

3. **(Optional) Create a salts.txt file:**
   If you want to use salts for your minipool creations, you can create a file named `salts.txt` in the same directory as the script. This file should contain a list of salts to use, one per line. You can create and edit this file using your favorite text editor. For example:

   ```
   nano salts.txt
   ```

   Then add your salts, one per line:

   ```
   salt1
   salt2
   salt3
   ```

   Replace "salt1", "salt2", etc., with your actual salt values.
   
   Note: Using salts is completely optional. If you don't create this file or if the file is empty, the script will function normally without using salts.

4. **Set up environment variables:**
   - Create a new `.env` file with your preferred text editor (e.g., nano, vim):
     ```
     nano .env
     ```
   - Set your Etherscan API key and add any other variables you would like to override the defaults with:
     ```
     API_KEY=your_api_key_here
     START_GAS=4.5
     PRIO_FEE=0.08
     # ... other variables set in .default.env ...
     ```

   To obtain an Etherscan API key:
   1. Go to https://etherscan.io/
   2. Sign up for an account if you don't have one
   3. Once logged in, navigate to your user profile and select "API Keys"
   4. Click on "Add" to create a new API key
   5. Copy the generated API key and paste it into your `.env` file on a single line that reads
   ```
   API_KEY=<your_api_key_here>
   ```
5. **Install required dependencies:**
   - Ensure you have `bc` (basic calculator) installed. On most Linux systems, it's pre-installed. If not, you can install it using your package manager:
     ```
     sudo apt-get install bc  # For Debian/Ubuntu
     sudo yum install bc      # For CentOS/RHEL
     ```
   - Install `jq`, a lightweight command-line JSON processor:
     ```
     sudo apt-get install jq  # For Debian/Ubuntu
     sudo yum install jq      # For CentOS/RHEL
     ```
   - Install `curl`, which is used for making HTTP requests:
     ```
     sudo apt-get install curl  # For Debian/Ubuntu
     sudo yum install curl      # For CentOS/RHEL
     ```
   - Ensure you have `sed` installed. It's typically pre-installed on most Linux systems.

   Note: The exact installation commands may vary depending on your specific Linux distribution. If you're using a different package manager, adjust the commands accordingly.

6. **Test the script:**
   Run the script with the `--dry-run` option to test without executing actual transactions:
   ```
   ./minilaunch.sh --dry-run
   ```

## Usage

To start the script:

```
./minilaunch.sh
```

To display the help section and see all available options:

```
./minilaunch.sh -h
```

This will show you all the available command-line options, including:

- `-r, --gasRampTime`: Set the target gas ramp time in hours for gas limit increase
- `-s, --sleepTime`: Set the time between attempts in seconds
- `-f, --startGas`: Set the starting gas limit
- `-e, --endGas`: Set the ending gas limit
- `-i, --prioFee`: Set the priority fee
- `--dry-run`: Run in dry-run mode (no transactions will be executed)
- `--never-exit`: Keep running indefinitely, even after successful minipool creation

The `--never-exit` option allows the script to continue running and attempting to create new minipools even after a successful creation, starting with startGas again for the new attempt. When this option is not used, the script will exit after successfully creating a minipool or when encountering an unexpected output. The option has no effect when running in dry-run mode.

1. If both `startGas` and `endGas` are specified:
   - The gas limit will gradually increase from `startGas` to `endGas` over the specified `gasRampTime`.
   - After the `gasRampTime` is reached, the script continues to run using the `endGas` value until a transaction can be executed.

2. If only `startGas` is specified (no `endGas`):
   - The script will use a static gas limit value (`startGas`) throughout its execution.
   - In this case, the `gasRampTime` parameter has no effect on the gas limit.

3. The script will continue running indefinitely until a transaction is successfully executed or manually stopped.

Example usage:

To run the script with a starting gas of 3.1 gwei, ending gas of 7 gwei, over a 24-hour gas ramp time, and in dry-run mode:

```
./minilaunch.sh -f 3.1 -e 7 -r 24 --dry-run
```

To run the script with a static gas limit of 4.5 gwei:

```
./minilaunch.sh -f 4.5
```

## Running in background

When a shell script is run from an SSH session, as soon as the pipe is broken and no outputs can be sent to the user, the script stops. In order to let it run even after the SSH session is terminated, follow these steps:

1. Start the job in the background and redirect its output to a file:  
    `./minilaunch.sh -f 3.9 -e 7.1 -i 0.11 -r 17 >> ./minilaunch.log 2>&1 &`

2. You can check the status of background jobs with:  
    `jobs`

3. If you need to bring it back to the foreground or manipulate it further:  
    `fg %<job_number>`

4. To kill the job:  
    `kill %<job_number>`

5. If you want the job to continue running even after you log out, you can `disown` it after starting it:  
    ```
     disown -h %1   # If you use bash.
     disown %1      # If you use zsh.
                    # Replace 1 with the job number if different in both cases
    ```

6. Since disowned jobs become regular processes, you can list them using `ps`:  
    `ps aux | grep minilaunch.sh`

7. If you need to stop a disowned job, you can use its `PID`:  
    `kill <PID>`

8. To watch the log entries continuously as they appear:  
    `tail -f minilaunch.log`

## Configuration Parameters

The following parameters can be configured in the `.default.env` file or rather, overridden in your `.env` file,
since .default.env is version controlled and should not be modified.

### API Configuration
- `API_URL`: The base URL for the Etherscan API. Change this if you're using a different network (e.g. testnet).
- `API_KEY`: Your Etherscan API key. Required for making API calls.

### Gas Price Settings
- `START_GAS`: The initial gas price (in Gwei) at which the script will start attempting to create minipools.
- `END_GAS`: The maximum gas price (in Gwei) the script will consider for creating minipools. Used in conjunction with `GAS_RAMP_TIME` for dynamic gas price adjustment.
- `GAS_MARGIN`: A multiplier applied to the current gas price to determine the adjusted gas price. The adjusted gas price is actually used for all checks, and since the transaction is submitted at the adjusted gas price, this provides a margin that should make reasonably sure the transaction will get included.
- `PRIO_FEE`: The priority fee (in Gwei) to be used when submitting the minipool create transaction.

### Pool Settings
- `MIN_POOL_SIZE`: The minimum amount of ETH required in the pool before attempting to create a minipool. Default is 24 ETH. To avoid race conditions where other bots have emptied the pool in the meantime, which would cause the transaction to fail.
- `BOND_SIZE`: The amount of ETH to be bonded when creating a minipool. Needed as parameter for the hasSufficientLiquidity check.

### Contract Addresses
- `OPR_DIST_CONTRACT_ADDR`: The address of the Operator Distributor contract.
- `SUPERNODE_ACC_ADDR`: The address of the Supernode Account contract.

### Script Behavior
- `SLEEP_NEXT`: The number of seconds to wait between each iteration of the main loop. This interval will be increased to a maximum of 5 minutes if the current gas price is too far above our targeted gas price, to avoid unnecessary checks.
- `GAS_RAMP_TIME`: The target time in hours for a gradual gas limit increase from `START_GAS` to `END_GAS`. The goal of this parameter is to meet the gas price "in the middle" if it doesn't drop to the desired level during the `GAS_RAMP_TIME`. The script will keep running after the `GAS_RAMP_TIME` has passed, using `END_GAS` for the gas limit.

### File Paths
- `SALT_FILE`: The path to the file containing salt values for minipool creation.

### Notifications
- `DISCORD_WEBHOOK`: The Discord webhook URL for sending notifications. If this value is empty, no notifications will be sent. See Discord's documentation on webhooks for more information on how to set this up.

Modifying these parameters will affect the behavior of the script:
- Adjusting gas settings will impact when transactions are sent.
- Updating contract addresses is necessary if you're interacting with different contracts.
- Altering script behavior settings will change how frequently the script checks conditions and how long it runs.
- Setting up the Discord webhook will enable notifications about important events during script execution.

Remember to keep your `.env` file secure and never commit it to version control, as it may contain sensitive information like API keys and webhook URLs.
