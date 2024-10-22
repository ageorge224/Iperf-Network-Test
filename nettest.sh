#!/bin/bash

# Function to log messages with color
log_message() {
    local color=$1
    local message=$2
    case $color in
    red) color_code="\e[31m" ;;
    green) color_code="\e[32m" ;;
    yellow) color_code="\e[33m" ;;
    blue) color_code="\e[34m" ;;
    magenta) color_code="\e[35m" ;;
    cyan) color_code="\e[36m" ;;
    white) color_code="\e[37m" ;;
    gray) color_code="\e[90m" ;;
    light_red) color_code="\e[91m" ;;
    light_green) color_code="\e[92m" ;;
    light_yellow) color_code="\e[93m" ;;
    light_blue) color_code="\e[94m" ;;
    light_magenta) color_code="\e[95m" ;;
    light_cyan) color_code="\e[96m" ;;
    NC) color_code="\e[0m" ;; # No Color
    *) color_code="" ;;
    esac
    echo -e "${color_code}${message}\e[0m" | tee -a "$log_file"
}

#  Variables
RUN_LOG="/tmp/nettest_log.txt"
SUDO_ASKPASS_PATH="$HOME/sudo_askpass.sh"
main_ip="192.168.1.169"
remotes=("192.168.1.248" "192.168.1.145" "192.168.1.238")
log_file="$HOME/network_test.log"
iperf_port=42069
dry_run=false # Default value for dry-run mode

# Enable error trapping
set -o errexit # Enable strict error checking
set -o nounset # Exit if an unset variable is used
set -o noglob  # Disable filename expansion
set -eE
set -o pipefail # trace ERR through pipes
set -o errtrace # trace ERR through 'time command' and other functions

# Function to restart the script
restart_script_function() {
    log_message yellow "Restarting script..."
    exec "$0" "$@"
}

# Function for custom action (SIGUSR1)
custom_action() {
    log_message blue "Performing custom action for SIGUSR1"
    load_exclusions "/home/ageorge/Desktop/Update-Script/exclusions_config"
    log_message green "Configuration reloaded successfully."
    echo "Configuration reloaded at $(date)" >>"$RUN_LOG"
}

# Cleanup function
cleanup_function() {
    log_message yellow "Performing cleanup..."
    echo "Cleanup completed at $(date)" >>"$RUN_LOG"
}

# Error handling function with detailed output and retry
handle_error() {
    local func_name="$1"
    local err="${2:-check}"
    local retry_command="${3:-}"
    local retry_count=0
    local max_retries=3
    local backtrace_file="/tmp/error_backtrace.txt"

    local file_name="${BASH_SOURCE[1]}"
    local line_number="${BASH_LINENO[0]}"
    local error_code="$err"
    local error_message="${BASH_COMMAND}"

    echo -e "\n(!) EXIT HANDLER:\n" >&2
    echo "FUNCTION:  ${func_name}" >&2
    echo "FILE:       ${file_name}" >&2
    echo "LINE:       ${line_number}" >&2
    echo -e "\nERROR CODE: ${error_code}" >&2
    echo -e "ERROR MESSAGE:\n${error_message}" >&2

    # Check specific error codes and provide custom handling
    case "$error_code" in
    1)
        log_message yellow "General error occurred. Consider checking permissions or syntax."
        ;;
    2)
        log_message yellow "Misuse of shell builtins. Verify the command syntax."
        ;;
    126)
        log_message yellow "Command invoked cannot execute. Check file permissions."
        ;;
    127)
        log_message yellow "Command not found. Ensure the command exists in your PATH."
        ;;
    130)
        log_message yellow "Script terminated by Ctrl+C (SIGINT)."
        ;;
    *)
        log_message yellow "An unexpected error occurred (Code: ${error_code})."
        ;;
    esac

    # Generate the backtrace
    echo -e "\nBACKTRACE IS:" >"$backtrace_file"
    local i=0
    while caller $i >>"$backtrace_file"; do
        ((i++))
    done
    cat "$backtrace_file" >&2

    # Retry logic if a command is specified
    set +e
    if [[ -n "$retry_command" ]]; then
        while [[ $retry_count -lt $max_retries ]]; do
            log_message yellow "Retrying after error... Attempt $((retry_count + 1))/$max_retries"
            if eval "$retry_command"; then
                log_message green "Retried successfully on attempt $((retry_count + 1))"
                set -e
                return 0
            fi
            ((retry_count++))
            sleep $(((RANDOM % 5) + (2 ** retry_count)))
        done
    fi
    set -e

    # If retries fail, perform cleanup and exit
    log_message red "All retries failed. Exiting script."
    cleanup_function

    exit 1
}

# Trap errors and signals
trap 'handle_error "$BASH_COMMAND" "$?"' ERR
trap 'echo "Script terminated prematurely" >> "$RUN_LOG"; exit 1' SIGINT SIGTERM
trap 'handle_error "SIGPIPE received" "$?"' SIGPIPE
trap 'log_message yellow "Restarting script due to SIGHUP"; restart_script_function' SIGHUP
trap 'log_message blue "Custom action for SIGUSR1"; custom_action' SIGUSR1
trap 'cleanup_function' EXIT

# Check if dry-run flag is set
if [[ "${1:-}" == "--dry-run" ]]; then
    dry_run=true
    log_message yellow "Dry-run mode enabled. No commands will be executed."
fi

# Function to validate and initialize variables
validate_variable() {
    local var_name="$1"
    local var_value="$2"
    local permissions="${3:-644}" # Default permissions if not specified

    if [[ -z "$var_value" ]]; then
        echo "Error: Variable $var_name is not set."
        exit 1
    fi

    if [[ ! -e "$var_value" ]]; then
        echo "File for $var_name does not exist. Creating $var_value."
        touch "$var_value" || {
            echo "Error: Unable to create file $var_value."
            exit 1
        }
    fi

    chmod "$permissions" "$var_value" || {
        echo "Error: Unable to set permissions on $var_value."
        exit 1
    }
    echo "Variable $var_name is valid. File exists at $var_value with permissions $permissions."
}

# Function to validate required commands
validate_commands() {
    {
        local required_commands=("ssh" "scp" "md5sum" "sudo" "apt-get" "iperf3")
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" &>/dev/null; then
                log_message red "Error: Required command not found: $cmd"
                exit 1
            fi
        done
    } || handle_error "validate_commands" "$?"
}

# Export SUDO_ASKPASS and use sudo -A for all sudo commands
export SUDO_ASKPASS="$SUDO_ASKPASS_PATH"

# Validate and initialize RUN_LOG
validate_variable "RUN_LOG" "$RUN_LOG" "644"
validate_variable "log_file" "$log_file" "644"
validate_commands

# Function to run SSH commands with sudo (dry-run aware)
ssh_sudo() {
    local remote_ip="$1"
    local command="$2"
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would execute SSH command on $remote_ip: sudo -S $command"
    else
        ssh -i "$HOME/.ssh/id_rsa" -o BatchMode=yes "ageorge@$remote_ip" "sudo -S $command"
    fi
}

# Function to start iperf server on remote machine (dry-run aware)
start_remote_iperf_server() {
    local remote_ip="$1"
    log_message blue "Starting iperf server on Remote ($remote_ip)..."
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would start iperf server on Remote ($remote_ip)"
    else
        ssh_sudo "$remote_ip" "pkill iperf3; nohup iperf3 -s -p $iperf_port > /dev/null 2>&1 & echo \$!"
    fi
}

# Function to check if iperf server is running on remote machine (dry-run aware)
check_remote_iperf_server() {
    local remote_ip="$1"
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would check if iperf server is running on Remote ($remote_ip)"
    else
        ssh_sudo "$remote_ip" "pgrep -f 'iperf3 -s -p $iperf_port'" >/dev/null
    fi
}

# Function to perform iperf test from Main to Remote (dry-run aware)
run_test_main_to_remote() {
    local remote_ip="$1"
    log_message yellow "Starting iperf test from Main ($main_ip) to Remote ($remote_ip)..."
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would run iperf test from Main ($main_ip) to Remote ($remote_ip)"
    else
        iperf3 -c "$remote_ip" -p "$iperf_port" -t 10 2>&1 | tee -a "$log_file" || handle_error "run_test_main_to_remote" "$?" "iperf3 -c $remote_ip -p $iperf_port -t 10"
    fi
}

# Function to perform iperf test from Remote to Main (dry-run aware)
run_test_remote_to_main() {
    local remote_ip="$1"
    log_message yellow "Starting iperf test from Remote ($remote_ip) to Main ($main_ip)..."
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would run iperf test from Remote ($remote_ip) to Main ($main_ip)"
    else
        ssh_sudo "$remote_ip" "iperf3 -c $main_ip -p $iperf_port -t 10" | tee -a "$log_file" || handle_error "run_test_remote_to_main" "$?" "ssh_sudo $remote_ip 'iperf3 -c $main_ip -p $iperf_port -t 10'"
    fi
}

# Verify sudo access before starting tests (dry-run aware)
if [[ "$dry_run" == true ]]; then
    log_message yellow "Dry-run: Would verify sudo privileges."
else
    if ! sudo -A true; then
        handle_error "sudo verification" "$?" "sudo -A true"
    fi
fi

# Start and verify iperf3 servers on remote machines (dry-run aware)
log_message blue "Starting and verifying iperf servers on remote machines..."
for remote_ip in "${remotes[@]}"; do
    pid=$(start_remote_iperf_server "$remote_ip")
    sleep 2
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would check iperf server on Remote ($remote_ip)"
    else
        if check_remote_iperf_server "$remote_ip"; then
            log_message green "Iperf server started successfully on Remote ($remote_ip) with PID $pid"
        else
            handle_error "check_remote_iperf_server" "$?" "check_remote_iperf_server '$remote_ip'"
        fi
    fi
done

# Ensure iperf server is running on Main (dry-run aware)
log_message blue "Starting iperf server on Main ($main_ip)..."
if [[ "$dry_run" == true ]]; then
    log_message yellow "Dry-run: Would start iperf server on Main ($main_ip)"
else
    sudo -A iperf3 -s -p "$iperf_port" &
    server_pid=$!
    sleep 2
fi

# Run tests for each remote machine (dry-run aware)
for remote_ip in "${remotes[@]}"; do
    run_test_main_to_remote "$remote_ip"
    run_test_remote_to_main "$remote_ip"
done

# Stop the iperf server on Main (dry-run aware)
log_message blue "Stopping iperf server on Main..."
if [[ "$dry_run" == true ]]; then
    log_message yellow "Dry-run: Would stop iperf server on Main"
else
    sudo -A kill "$server_pid" || handle_error "kill_main_iperf_server" "$?" "sudo -A kill $server_pid"
fi

# Stop iperf3 servers on remote machines (dry-run aware)
log_message blue "Stopping iperf servers on remote machines..."
for remote_ip in "${remotes[@]}"; do
    if [[ "$dry_run" == true ]]; then
        log_message yellow "Dry-run: Would stop iperf server on Remote ($remote_ip)"
    else
        ssh_sudo "$remote_ip" "pkill iperf3" || handle_error "pkill_remote_iperf_server" "$?" "ssh_sudo '$remote_ip' 'pkill iperf3'"
    fi
done

log_message green "Network tests completed."
