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

3. **Set up environment variables:**
   - Copy the `.default.env` file to create a new `.env` file:
     ```
     cp .default.env .env
     ```
   - Edit the `.env` file with your preferred text editor (e.g., nano, vim):
     ```
     nano .env
     ```
   - Set your API key and adjust other variables as needed:
     ```
     API_KEY=your_api_key_here
     GAS_LIMIT=4.5
     PRIO_FEE=0.08
     # ... other variables ...
     ```

4. **Install required dependencies:**
   - Ensure you have `bc` (basic calculator) installed. On most Linux systems, it's pre-installed. If not, you can install it using your package manager:
     ```
     sudo apt-get install bc  # For Debian/Ubuntu
     sudo yum install bc      # For CentOS/RHEL
     ```

5. **Test the script:**
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

- `-r, --runtime`: Set the target runtime in hours for gas limit increase
- `-s, --sleepTime`: Set the time between attempts in seconds
- `-f, --startGas`: Set the starting gas limit
- `-e, --endGas`: Set the ending gas limit
- `-i, --prioFee`: Set the priority fee
- `--dry-run`: Run in dry-run mode (no transactions will be executed)

Important notes on script behavior:

1. If both `startGas` and `endGas` are specified:
   - The gas limit will gradually increase from `startGas` to `endGas` over the specified `runtime`.
   - After the `runtime` is reached, the script continues to run using the `endGas` value until a transaction can be executed.

2. If only `startGas` is specified (no `endGas`):
   - The script will use a static gas limit value (`startGas`) throughout its execution.
   - In this case, the `runtime` parameter has no effect on the gas limit.

3. The script will continue running indefinitely until a transaction is successfully executed or manually stopped.

Example usage:

To run the script with a starting gas of 3.1 gwei, ending gas of 7 gwei, over a 24-hour period, and in dry-run mode:

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
    `disown -h %1  # Replace 1 with the job number if different`

6. Since disowned jobs become regular processes, you can list them using `ps`:  
    `ps aux | grep minilaunch.sh`

7. If you need to stop a disowned job, you can use its `PID`:  
    `kill <PID>`

8. To watch the log entries continuously as they appear:  
    `tail -f minilaunch.log`
