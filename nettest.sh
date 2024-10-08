#!/bin/bash

# Variables
SUDO_ASKPASS_PATH="$HOME/sudo_askpass.sh"
main_ip="192.168.1.169"
remotes=("192.168.1.248" "192.168.1.145" "192.168.1.238")
log_file="$HOME/network_test.log"
iperf_port=42069

# Colors for output
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # No Color

# Export SUDO_ASKPASS and use sudo -A for all sudo commands
export SUDO_ASKPASS="$SUDO_ASKPASS_PATH"

# Function to log messages with color and spacing
log_message() {
    local message="$1"
    local color="${2:-$NC}"
    echo -e "${color}$(date +'%Y-%m-%d %H:%M:%S') - $message${NC}" | tee -a "$log_file"
}

# Function to run SSH commands with sudo
ssh_sudo() {
    local remote_ip="$1"
    local command="$2"
    ssh -i "$HOME/.ssh/id_rsa" -o BatchMode=yes "ageorge@$remote_ip" "sudo -S $command"
}

# Function to start iperf server on remote machine
start_remote_iperf_server() {
    local remote_ip="$1"
    log_message "Starting iperf server on Remote ($remote_ip)..." "$BLUE"
    ssh_sudo "$remote_ip" "pkill iperf3; nohup iperf3 -s -p $iperf_port > /dev/null 2>&1 & echo \$!"
}

# Function to check if iperf server is running on remote machine
check_remote_iperf_server() {
    local remote_ip="$1"
    ssh_sudo "$remote_ip" "pgrep -f 'iperf3 -s -p $iperf_port'" >/dev/null
    return $?
}

# Function to perform iperf test from Main to Remote
run_test_main_to_remote() {
    local remote_ip="$1"
    log_message "Starting iperf test from Main ($main_ip) to Remote ($remote_ip)..." "$YELLOW"
    iperf3 -c "$remote_ip" -p "$iperf_port" -t 10 2>&1 | tee -a "$log_file"
    if [[ $? -eq 0 ]]; then
        log_message "Test from Main to Remote ($remote_ip) completed successfully." "$GREEN"
    else
        log_message "Test from Main to Remote ($remote_ip) failed. See log for details." "$RED"
    fi
}

# Function to perform iperf test from Remote to Main
run_test_remote_to_main() {
    local remote_ip="$1"
    log_message "Starting iperf test from Remote ($remote_ip) to Main ($main_ip)..." "$YELLOW"
    ssh_sudo "$remote_ip" "iperf3 -c $main_ip -p $iperf_port -t 10" | tee -a "$log_file"
    if [[ $? -eq 0 ]]; then
        log_message "Test from Remote ($remote_ip) to Main completed successfully." "$GREEN"
    else
        log_message "Test from Remote ($remote_ip) to Main failed." "$RED"
    fi
}

# Verify sudo access before starting tests
if ! sudo -A true; then
    log_message "Failed to obtain sudo privileges. Please check your sudo_askpass.sh script." "$RED"
    exit 1
fi

# Start and verify iperf3 servers on remote machines
log_message "Starting and verifying iperf servers on remote machines..." "$BLUE"
for remote_ip in "${remotes[@]}"; do
    pid=$(start_remote_iperf_server "$remote_ip")
    sleep 2
    if check_remote_iperf_server "$remote_ip"; then
        log_message "Iperf server started successfully on Remote ($remote_ip) with PID $pid" "$GREEN"
    else
        log_message "Failed to start iperf server on Remote ($remote_ip)" "$RED"
        exit 1
    fi
done

# Ensure iperf server is running on Main
log_message "Starting iperf server on Main ($main_ip)..." "$BLUE"
sudo -A iperf3 -s -p "$iperf_port" &
server_pid=$!
sleep 2

# Run tests for each remote machine
for remote_ip in "${remotes[@]}"; do
    run_test_main_to_remote "$remote_ip"
    run_test_remote_to_main "$remote_ip"
done

# Stop the iperf server on Main
log_message "Stopping iperf server on Main..." "$BLUE"
sudo -A kill "$server_pid"

# Stop iperf3 servers on remote machines
log_message "Stopping iperf servers on remote machines..." "$BLUE"
for remote_ip in "${remotes[@]}"; do
    ssh_sudo "$remote_ip" "pkill iperf3"
done

log_message "Network tests completed." "$GREEN"
