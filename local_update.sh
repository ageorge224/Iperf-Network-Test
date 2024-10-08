#!/bin/bash

# Initialize unset variables with defaults
AG_backup="${AG_backup:-192.168.1.238}"
BACKUP_DIR="${BACKUP_DIR:-/default/backup/dir}"
LOG_FILE="${LOG_FILE:-/default/log/file.log}"
REMOTE_USER="${REMOTE_USER:-ageorge}"
VERSION="${VERSION:-1.0.0}"
CHANGELOG_FILE="${CHANGELOG_FILE:-/default/changelog.txt}"
REMOTE_LOG="${REMOTE_LOG:-/default/remote_log.txt}"
RUN_LOG="${RUN_LOG:-/default/run_log.txt}"
LOCAL_UPDATE_ERROR="${LOCAL_UPDATE_ERROR:-/default/local_update_error.log}"
LOCAL_UPDATE_DEBUG="${LOCAL_UPDATE_DEBUG:-/default/local_update_debug.log}"
BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-/default/backup_log_dir}"
BACKUP_LOG_FILE="${BACKUP_LOG_FILE:-/default/backup_log_file.log}"

# Enable error trapping
set -o errexit # Enable strict error checking
#set -o nounset # Exit if an unset variable is used
set -o noglob # Disable filename expansion
set -eE

handle_error() {
    local func_name="$1"
    local err="${2:-check}"
    local retry_command="$3"
    local retry_count=0
    local max_retries=3
    local backtrace_file="/tmp/error_backtrace.txt"

    # Log the error message
    log_message red "Error in function '${func_name}': ${err}"

    # Write the error to a specific error log file
    echo "Error in function '${func_name}': ${err}" >>"$LOCAL_UPDATE_ERROR"

    # Generate backtrace
    echo "Backtrace:" >>"$backtrace_file"
    local i=0
    while caller $i >>"$backtrace_file"; do
        ((i++))
    done

    # Temporarily disable errexit
    set +e

    # Implement retry logic
    while [[ $retry_count -lt $max_retries ]]; do
        log_message yellow "Retrying after error... Attempt $((retry_count + 1))/$max_retries"

        # Retry the failed operation
        if eval "$retry_command"; then
            log_message green "Retried successfully on attempt $((retry_count + 1))"
            return 0
        fi

        # Increase the retry count
        ((retry_count++))

        # Optional: Add a delay between retries (e.g., 5 seconds)
        sleep 5
    done

    # Re-enable errexit
    set -e

    # If all retries fail, log the failure, print the backtrace, and exit the script
    log_message red "All retries failed. Exiting script."
    cat "$backtrace_file"
    exit 1
}

# Trap errors and signals
trap 'handle_error "$BASH_COMMAND" "$?"' ERR
trap 'echo "Script terminated prematurely" >> "$RUN_LOG"; exit 1' SIGINT SIGTERM
trap 'handle_error "SIGPIPE received" "$?"' SIGPIPE

# Variables
VERSION="1.2.96"
SCRIPT_NAME="local_update.sh"
REMOTE_USER="ageorge"
pihole="192.168.1.248"
pihole2="192.168.1.145"
AG_backup="192.168.1.238"
BACKUP_LOG_DIR="/home/ageorge/.local_update_logs"
BACKUP_DIR="/home/ageorge/Documents/Backups"
BACKUP_DIR2="/mnt/Nvme500Data/Update Backups"
REMOTE_LOG="/home/ageorge/Desktop/remote_update.log"
CHANGELOG_FILE="$BACKUP_DIR/changelog.txt"
LOG_FILE="/tmp/local_update.log"
pihole_log="$BACKUP_LOG_DIR/remote_update.log"
pihole2_log="$BACKUP_LOG_DIR/remote_update2.log"
AG_Backup_log="$BACKUP_LOG_DIR/remote_update3.log"
BACKUP_LOG_FILE="$BACKUP_LOG_DIR/local_update.log"
pihole_local="/tmp/remote_update.sh"
pihole2_local="/tmp/remote_update2.sh"
AG_Backup_local="/tmp/remote_update3.sh"
pihole_Remote="/tmp/remote_update.sh"
pihole2_Remote="/tmp/remote_update2.sh"
AG_Backup_Remote="/tmp/remote_update3.sh"
SUDO_ASKPASS_PATH="$HOME/sudo_askpass.sh"
RUN_LOG="/tmp/run_log.txt"
CHECKSUM_FILE="/tmp/remote_update.sh.md5"
LOCAL_UPDATE_ERROR="$BACKUP_LOG_DIR/local_update_error.log"
LOCAL_UPDATE_DEBUG="$BACKUP_LOG_DIR/local_update_debug.log"
centralized_error_log="$BACKUP_LOG_DIR/centralized_error_log.log"
SEEN_ERRORS_FILE="$BACKUP_LOG_DIR/seen_errors.log"
CACHE_DIR="$HOME/.logscan_cache"
temp_error_counts="$CACHE_DIR/temp_error_counts.txt"
LAST_RUN_FILE="$CACHE_DIR/last_run"
DRY_RUN=false

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
    *) color_code="" ;;
    esac
    echo -e "${color_code}${message}\e[0m" | tee -a "$LOG_FILE"
}

# Function to check dry-run mode and return a status code
check_dry_run_mode() {
    if $DRY_RUN; then
        echo -e "\e[33m[DRY-RUN MODE] The following actions will be taken (no actual changes will be made):\e[0m"
        return 0
    fi

    return 1
}

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --dry-run    Run in dry-run mode (no actual changes)"
    echo "  --help       Display this help message"
}

# Export SUDO_ASKPASS
export SUDO_ASKPASS="$SUDO_ASKPASS_PATH"

# Initialize RUN_LOG
true >"$RUN_LOG"

# Parse command-line arguments
if [[ $# -eq 0 ]]; then
    echo "No arguments provided. Using default settings."
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo -e "\e[31mError: Invalid option: $1\e[0m" >&2
            usage
            exit 1
            ;;
        esac
        shift
    done
fi

# Example of using the parsed arguments
if [[ "$DRY_RUN" = true ]]; then
    echo "Running in dry-run mode"
else
    echo "Running in normal mode"
fi

# Define the box characters with color codes
u_left="\e[36m╭\e[0m"
u_right="\e[36m╮\e[0m"
b_left="\e[36m╰\e[0m"
b_right="\e[36m╯\e[0m"
v_bar="\e[36m│\e[0m"
h_bar="\e[36m─\e[0m"

# Header creation and display function
print_header() {
    local script_name=$SCRIPT_NAME
    local version=$VERSION
    local author="Anthony George"
    local description="A script for performing local and remote system updates with backup functionality"
    local date
    date=$(date +"%Y-%m-%d")

    calc_max_width() {
        local max_width=80
        local temp_width

        temp_width=$((${#script_name} + ${#version} + 4))
        [[ $temp_width -gt $max_width ]] && max_width=$temp_width

        temp_width=$((${#date} + ${#author} + 15))
        [[ $temp_width -gt $max_width ]] && max_width=$temp_width

        local vars=("REMOTE_USER"
            "pihole"
            "BACKUP_DIR"
            "BACKUP_DIR2"
            "LOG_FILE"
            "BACKUP_LOG_FILE"
            "DRY_RUN")
        for var in "${vars[@]}"; do
            value="${!var}"
            temp_width=$((${#var} + ${#value} + 24))
            [[ $temp_width -gt $max_width ]] && max_width=$temp_width
        done

        echo $((max_width + 4))
    }

    local width
    width=$(calc_max_width)
    local content_width=$((width - 2)) # Subtract 2 for the left and right borders

    print_line() {
        printf "\e[36m%s\e[0m\n" "$(printf "%${width}s" | tr ' ' "${h_bar}")"
    }

    print_content_line() {
        printf "\e[36m|\e[0m %-${content_width}s \e[36m|\e[0m\n" "$1"
    }

    print_wrapped_text() {
        local text="$1"
        local prefix="${2:-check}"
        local max_length=$((content_width - ${#prefix}))
        local line=""
        for word in $text; do
            if ((${#line} + ${#word} + 1 > max_length)); then
                print_content_line "$(printf "%-${#prefix}s%s" "$prefix" "$line")"
                line="$word"
                prefix="  "
            else
                [[ -n $line ]] && line+=" "
                line+="$word"
            fi
        done
        [[ -n $line ]] && print_content_line "$(printf "%-${#prefix}s%s" "$prefix" "$line")"
    }

    echo -e "\e[36m+$(printf "%${width}s" | tr ' ' "${h_bar}")+\e[0m"
    printf "\e[36m|\e[1;33m %-${content_width}s \e[36m|\e[0m\n" "$script_name v$version"
    print_line
    print_content_line "$(printf "%-15s\e[32m%s" "Date:" "$date")"
    print_content_line "$(printf "%-15s\e[32m%s" "Author:" "$author")"
    print_line
    print_wrapped_text "$description" "Description: "
    print_line
    print_content_line "\e[1mConfiguration Variables:"
    local vars=("REMOTE_USER"
        "pihole"
        "BACKUP_DIR"
        "BACKUP_DIR2"
        "LOG_FILE"
        "BACKUP_LOG_FILE"
        "DRY_RUN")
    for var in "${vars[@]}"; do
        value="${!var}"
        print_content_line "$(printf "%-20s \e[32m%s" "$var:" "$value")"
    done
    echo -e "\e[36m+$(printf "%${width}s" | tr ' ' "${h_bar}")+\e[0m"
    echo
}

print_header

# Function to validate log files
validate_log_files() {
    {
        local log_files=("$LOG_FILE"
            "$BACKUP_LOG_FILE"
            "$REMOTE_LOG"
            "$pihole_log"
            "$pihole2_log"
            "$AG_Backup_log"
            "$centralized_error_log"
            "$LOCAL_UPDATE_ERROR"
            "$LOCAL_UPDATE_DEBUG")
        for file in "${log_files[@]}"; do
            local dir
            dir=$(dirname "$file")
            if [[ ! -d "$dir" ]]; then
                log_message red "Error: Directory for log file does not exist: $dir"
                exit 1
            fi
            if [[ ! -w "$dir" ]]; then
                log_message red "Error: Cannot write to log directory: $dir"
                exit 1
            fi
        done
    } || handle_error "validate_log_files" "$?"
}

# Set this to false to suppress non-error output
SHOW_OUTPUT=false

# Function to conditionally echo messages
conditional_echo() {
    if $SHOW_OUTPUT; then
        echo "$@"
    fi
}

# shellcheck disable=SC2029
# Function to check file existence, create if needed, and set permissions
check_and_create_remote_file() {
    local user_host="$1"
    local remote_path="${2:-check}"
    local log_file="$3"

    ssh "$user_host" "

        # Check if file exists
        if [ ! -f \"$remote_path\" ]; then
            # Create the file if it doesn't exist
            mkdir -p \$(dirname \"$remote_path\") && touch \"$remote_path\" || { echo \"Failed to create file: $remote_path\"; exit 1; }
            echo \"Created file: $remote_path\"
        else
            echo \"File already exists: $remote_path\"
        fi

        # Set permissions (adjust as needed)
        chmod 644 \"$remote_path\" || { echo \"Failed to set permissions for: $remote_path\"; exit 1; }
        echo \"Set permissions for: $remote_path\"

        # Ensure the directory for the log file exists
        mkdir -p \$(dirname \"$log_file\") || { echo \"Failed to create directory for log file\"; exit 1; }

        # Check if log file exists, create if it doesn't, and set permissions
        if [ ! -f \"$log_file\" ]; then
            touch \"$log_file\" || { echo \"Failed to create log file: $log_file\"; exit 1; }
            echo \"Created log file: $log_file\"
        else
            echo \"Log file already exists: $log_file\"
        fi
        chmod 644 \"$log_file\" || { echo \"Failed to set permissions for log file: $log_file\"; exit 1; }
        echo \"Set permissions for log file: $log_file\"
    " || return 1

    conditional_echo "Successfully processed $remote_path and $log_file on $user_host"
}

# Main function to process all remote files
process_remote_files() {
    local -a remote_configs=(
        "ageorge@192.168.1.248 /tmp/remote_update /home/ageorge/Desktop/remote_update.log"
        "ageorge@192.168.1.145 /tmp/remote_update /home/ageorge/Desktop/remote_update2.log"
        "ageorge@192.168.1.238 /tmp/remote_update /home/ageorge/Desktop/remote_update3.log"
    )

    for config in "${remote_configs[@]}"; do
        read -r user_host remote_path log_file <<<"$config"

        local retry_count=0
        local max_retries=3

        while [[ $retry_count -lt $max_retries ]]; do
            if check_and_create_remote_file "$user_host" "$remote_path" "$log_file"; then
                conditional_echo "Successfully processed $remote_path and $log_file on $user_host"
                break
            else
                handle_error "check_and_create_remote_file" "Failed to process $remote_path on $user_host"
                ((retry_count++))
            fi
        done
    done
}

# Call the main function
process_remote_files

# Function to validate SSH connection
validate_ssh_connection() {
    {
        if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$pihole" exit; then
            log_message red "Error: Cannot establish SSH connection to $REMOTE_USER@$pihole"
            exit 1
        fi
        if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$pihole2" exit; then
            log_message red "Error: Cannot establish SSH connection to $REMOTE_USER@$pihole2"
            exit 1
        fi
        if ! ssh -q -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_USER@$AG_backup" exit; then
            log_message red "Error: Cannot establish SSH connection to $REMOTE_USER@$AG_backup"
            exit 1
        fi
    } || handle_error "validate_ssh_connection" "$?"
}

# Function to validate required commands
validate_commands() {
    {
        local required_commands=("ssh" "scp" "md5sum" "sudo" "apt-get")
        for cmd in "${required_commands[@]}"; do
            if ! command -v "$cmd" &>/dev/null; then
                log_message red "Error: Required command not found: $cmd"
                exit 1
            fi
        done
    } || handle_error "validate_commands" "$?"
}

# Function to validate changelog
validate_changelog() {
    {
        if [[ ! -f "$CHANGELOG_FILE" ]]; then
            log_message yellow "Warning: CHANGELOG_FILE does not exist. Creating it."
            touch "$CHANGELOG_FILE" || {
                log_message red "Error: Failed to create CHANGELOG_FILE"
                exit 1
            }
        elif [[ ! -w "$CHANGELOG_FILE" ]]; then
            log_message red "Error: CHANGELOG_FILE is not writable"
            exit 1
        fi
    } || handle_error "validate_changelog" "$?"
}

# Function to validate the SEEN_ERRORS_FILE
validate_seen_errors_file() {
    {
        if [[ ! -f "$SEEN_ERRORS_FILE" ]]; then
            log_message yellow "SEEN_ERRORS_FILE does not exist. Creating it."
            touch "$SEEN_ERRORS_FILE" || {
                log_message red "Error: Failed to create SEEN_ERRORS_FILE"
                exit 1
            }
        elif [[ ! -w "$SEEN_ERRORS_FILE" ]]; then
            log_message red "Error: SEEN_ERRORS_FILE is not writable"
            exit 1
        fi
    } || handle_error "validate_seen_errors_file" "$?"
}

# Function to validate variables
validate_variablesv2() {
    validate_log_files
    validate_ssh_connection
    validate_commands
    validate_changelog
    validate_seen_errors_file

    # Additional variable checks
    if [[ -z "$VERSION" ]]; then
        log_message red "Error: VERSION is not set"
        exit 1
    fi

    if [[ -z "$SCRIPT_NAME" ]]; then
        log_message red "Error: SCRIPT_NAME is not set"
        exit 1
    fi

    if [[ -z "$REMOTE_USER" ]]; then
        log_message red "Error: REMOTE_USER is not set"
        exit 1
    fi

    if [[ -z "$pihole" ]]; then
        log_message red "Error: pihole is not set"
        exit 1
    fi

    if [[ -z "$pihole2" ]]; then
        log_message red "Error: pihole is not set"
        exit 1
    fi

    if [[ -z "$AG_backup" ]]; then
        log_message red "Error: pihole is not set"
        exit 1
    fi

    if ! validate_ip "$pihole"; then
        log_message red "Error: Invalid IP address for pihole"
        exit 1
    fi

    if ! validate_ip "$pihole2"; then
        log_message red "Error: Invalid IP address for pihole"
        exit 1
    fi

    if ! validate_ip "$AG_backup"; then
        log_message red "Error: Invalid IP address for pihole"
        exit 1
    fi

    if [[ ! -d "$BACKUP_DIR2" ]]; then
        log_message red "Error: BACKUP_DIR2 does not exist"
        exit 1
    fi

    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_message red "Error: BACKUP_DIR does not exist"
        exit 1
    fi

    if [[ ! -f "$SUDO_ASKPASS_PATH" ]]; then
        log_message red "Error: SUDO_ASKPASS_PATH file does not exist"
        exit 1
    fi
}

check_restart_required() {

    # Use a compound command to group the code and catch errors
    {
        if [ -f /var/run/reboot-required ]; then
            log_message red "\nRemote Machine needs restarting\n"
            if [ -f /var/run/reboot-required.pkgs ]; then
                log_message blue "Packages requiring restart:"
                log_message blue "\n$(cat /var/run/reboot-required.pkgs)\n"
            fi
        else
            log_message blue "\nNo restart required\n"
        fi

        log_message blue "Time since last reboot:"
        log_message blue "\n$(uptime)\n"
    } || {
        exit_code=$?
        handle_error "check_restart_required" "Failed to check restart status: ${exit_code}"
    }
}

check_restart_required

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a ip_parts <<<"$ip"
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to verify and create directories if they don't exist
verify_and_create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_message yellow "Directory $dir does not exist. Creating it..."
        mkdir -p "$dir" || {
            log_message red "Failed to create directory: $dir"
            exit 1
        }
    fi
    if [[ ! -w "$dir" ]]; then
        log_message red "Cannot write to directory: $dir"
        exit 1
    fi
}

# Function to verify file paths
verify_file_path() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    verify_and_create_directory "$dir"
    if [[ ! -f "$file" && "${2:-check}" != "create" ]]; then
        log_message red "File does not exist: $file"
        exit 1
    fi
    if [[ "${2:-check}" == "create" && ! -f "$file" ]]; then
        touch "$file" || {
            log_message red "Failed to create file: $file"
            exit 1
        }
    fi
    if [[ ! -w "$file" ]]; then
        log_message red "Cannot write to file: $file"
        exit 1
    fi
}

# Verify and create necessary directories and files
verify_and_create_directory "$BACKUP_DIR"
verify_and_create_directory "$BACKUP_DIR2"
verify_and_create_directory "$BACKUP_LOG_DIR"
verify_file_path "$CHANGELOG_FILE" "create"
verify_file_path "$LOG_FILE" "create"
verify_file_path "$pihole_log" "create"
verify_file_path "$BACKUP_LOG_FILE" "create"
verify_file_path "$centralized_error_log" "create"
verify_file_path "$SUDO_ASKPASS_PATH"
verify_file_path "$RUN_LOG" "create"
verify_file_path "$CHECKSUM_FILE" "create"
verify_file_path "$SEEN_ERRORS_FILE" "create"
verify_file_path "$LOCAL_UPDATE_ERROR" "create"
verify_file_path "$LOCAL_UPDATE_DEBUG" "create"
verify_file_path "$pihole_local" "create"
verify_file_path "$pihole2_local" "create"
verify_file_path "$AG_Backup_local" "create"
verify_file_path "$pihole2_log" "create"
verify_file_path "$AG_Backup_log" "create"

# shellcheck disable=SC2086
# shellcheck disable=SC2029
# Function to validate variables and create remote locations
validate_variables() {
    local piholes=("$pihole" "$pihole2" "$AG_backup")
    local remote_scripts=("$pihole_Remote" "$pihole2_Remote" "$AG_Backup_Remote")

    for i in "${!piholes[@]}"; do
        local host="${piholes[$i]}"
        local script="${remote_scripts[$i]}"

        # Create remote script and set permissions
        ssh "$REMOTE_USER@$host" "
            if [[ ! -f $script ]]; then
                touch $script && chmod 755 $script || {
                    echo 'Error: Failed to create or set permissions for $script'
                    exit 1
                }
            fi
        " || {
            log_message red "Error: Failed to create or set permissions for $script on $host"
            exit 1
        }

        # Check if REMOTE_LOG exists and is writable, create if not
        ssh "$REMOTE_USER@$host" "
            if [[ ! -f $REMOTE_LOG ]]; then
                touch $REMOTE_LOG && chmod 644 $REMOTE_LOG || {
                    echo 'Error: Failed to create or set permissions for $REMOTE_LOG'
                    exit 1
                }
            elif [[ ! -w $REMOTE_LOG ]]; then
                chmod 644 $REMOTE_LOG || {
                    echo 'Error: Failed to set write permissions for $REMOTE_LOG'
                    exit 1
                }
            fi
        " || {
            log_message red "Error: Failed to create or set permissions for REMOTE_LOG on $host"
            exit 1
        }

        # Ensure the directory for REMOTE_LOG is writable
        ssh "$REMOTE_USER@$host" "
            if [[ ! -w $(dirname $REMOTE_LOG) ]]; then
                chmod 755 $(dirname $REMOTE_LOG) || {
                    echo 'Error: Failed to set write permissions for REMOTE_LOG directory'
                    exit 1
                }
            fi
        " || {
            log_message red "Error: Failed to set permissions for REMOTE_LOG directory on $host"
            exit 1
        }

        # Ensure the directory for remote script exists and is writable
        ssh "$REMOTE_USER@$host" "
            if [[ ! -d $(dirname $script) ]]; then
                mkdir -p $(dirname $script) && chmod 755 $(dirname $script) || {
                    echo 'Error: Failed to create or set permissions for remote script directory'
                    exit 1
                }
            elif [[ ! -w $(dirname $script) ]]; then
                chmod 755 $(dirname $script) || {
                    echo 'Error: Failed to set write permissions for remote script directory'
                    exit 1
                }
            fi
        " || {
            log_message red "Error: Failed to create or set permissions for remote script directory on $host"
            exit 1
        }
    done
}

# Call validate_variables after setting up all paths
validate_variables
validate_variablesv2

# Function to make Remote_Script3
create_remote_script3() {
    local available_space
    available_space=$(df -P "$(dirname "$AG_Backup_local")" | awk 'NR==2 {print $4}')

    # Check if available space is below a threshold (e.g., 1024 MB)
    if [[ $available_space -lt 1024 ]]; then
        echo "Insufficient disk space for remote script. Required: 1GB"
        exit 1
    fi

    # Writing the remote script content to file
    cat <<'EOF' >"$AG_Backup_local"
#!/bin/bash

# Initialize unset variables with defaults
AG_backup="${AG_backup:-192.168.1.238}"
BACKUP_DIR="${BACKUP_DIR:-/default/backup/dir}"
LOG_FILE="${LOG_FILE:-/default/log/file.log}"
REMOTE_USER="${REMOTE_USER:-ageorge}"
VERSION="${VERSION:-1.0.0}"
CHANGELOG_FILE="${CHANGELOG_FILE:-/default/changelog.txt}"
REMOTE_LOG="${REMOTE_LOG:-/default/remote_log.txt}"
RUN_LOG="${RUN_LOG:-/default/run_log.txt}"
LOCAL_UPDATE_ERROR="${LOCAL_UPDATE_ERROR:-/default/local_update_error.log}"
LOCAL_UPDATE_DEBUG="${LOCAL_UPDATE_DEBUG:-/default/local_update_debug.log}"
BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-/default/backup_log_dir}"
BACKUP_LOG_FILE="${BACKUP_LOG_FILE:-/default/backup_log_file.log}"


# Enable error trapping
set -o errexit # Enable strict error checking
#set -o nounset # Exit if an unset variable is used
set -o noglob # Disable filename expansion
set -eE

handle_error() {
    local func_name="$1"
    local err="${2:-check}"
    local retry_command="$3"
    local retry_count=0
    local max_retries=3
    local backtrace_file="/tmp/error_backtrace.txt"

    # Log the error message
    log_message red "Error in function '${func_name}': ${err}"

    # Write the error to a specific error log file
    echo "Error in function '${func_name}': ${err}" >>"$LOCAL_UPDATE_ERROR"

    # Generate backtrace
    echo "Backtrace:" >>"$backtrace_file"
    local i=0
    while caller $i >>"$backtrace_file"; do
        ((i++))
    done

    # Temporarily disable errexit
    set +e

    # Implement retry logic
    while [[ $retry_count -lt $max_retries ]]; do
        log_message yellow "Retrying after error... Attempt $((retry_count + 1))/$max_retries"

        # Retry the failed operation
        if eval "$retry_command"; then
            log_message green "Retried successfully on attempt $((retry_count + 1))"
            return 0
        fi

        # Increase the retry count
        ((retry_count++))

        # Optional: Add a delay between retries (e.g., 5 seconds)
        sleep 5
    done

    # Re-enable errexit
    set -e

    # If all retries fail, log the failure, print the backtrace, and exit the script
    log_message red "All retries failed. Exiting script."
    cat "$backtrace_file"
    exit 1
}


# Trap errors and signals
trap 'handle_error "$BASH_COMMAND" "$?"' ERR
trap 'echo "Script terminated prematurely" >> "$RUN_LOG"; exit 1' SIGINT SIGTERM
trap 'handle_error "SIGPIPE received" "$?"' SIGPIPE

VERSION="1.2 (AgeorgeBackup)"
LOG_FILE="/tmp/remote_update.log"
BACKUP_LOG_DIR="$HOME/Desktop"
BACKUP_LOG_FILE="$BACKUP_LOG_DIR/remote_update3.log"
SUDO_ASKPASS_PATH="$HOME/sudo_askpass.sh"
RUN_LOG="/tmp/remote_run_log.txt"
ERROR_LOG="/tmp/remote_error_log.txt"
REMOTE_SCRIPT_LOCAL3="/tmp/remote_update3.sh"
# shellcheck disable=SC2269
DRY_RUN="$DRY_RUN" # Pass DRY_RUN from the main script
HostnameID="AGeorge-Backup.home"

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
    *) color_code="" ;;
    esac
    echo -e "${color_code}${message}\e[0m" | tee -a "$LOG_FILE"
}

# Export SUDO_ASKPASS
export SUDO_ASKPASS="$SUDO_ASKPASS_PATH"

# Initialize RUN_LOG and ERROR_LOG
true >"$RUN_LOG"
true >"$ERROR_LOG"

# Validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a ip_parts <<<"$ip"
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

verify_and_create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_message yellow "Directory $dir does not exist. Creating it..."
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! mkdir -p "$dir"; then
                handle_error "verify_and_create_directory" "Failed to create directory: $dir"
            fi
        else
            log_message yellow "[DRY RUN] Would create directory: $dir"
        fi
    fi
    if [[ ! -w "$dir" && "$DRY_RUN" != "true" ]]; then
        handle_error "verify_and_create_directory" "Cannot write to directory: $dir"
    fi
}

verify_file_path() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    if ! verify_and_create_directory "$dir"; then
        handle_error "verify_file_path" "Failed to verify/create directory for file: $file"
    fi
    if [[ ! -f "$file" && "${2:-check}" != "create" ]]; then
        handle_error "verify_file_path" "File does not exist: $file"
    fi
    if [[ "${2:-check}" == "create" && ! -f "$file" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! touch "$file"; then
                handle_error "verify_file_path" "Failed to create file: $file"
            fi
        else
            log_message yellow "[DRY RUN] Would create file: $file"
        fi
    fi
    if [[ ! -w "$file" && "$DRY_RUN" != "true" ]]; then
        handle_error "verify_file_path" "Cannot write to file: $file"
    fi
}

# Validation checks
validate_remote_environment() {
    if [[ -z "$VERSION" ]]; then
        handle_error "validate_remote_environment" "VERSION is not set"
    fi

    # Verify and create necessary directories and files
    verify_file_path "$SUDO_ASKPASS_PATH" || return 1
    verify_file_path "$RUN_LOG" "create" || return 1
    verify_file_path "$ERROR_LOG" "create" || return 1
    verify_file_path "$REMOTE_SCRIPT_LOCAL3" "create" || return 1

    # Check for required commands
    local required_commands=("ssh" "scp" "md5sum" "sudo" "apt-get")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            handle_error "validate_remote_environment" "Required command not found: $cmd"
        fi
    done

    return 0
}

# Function to generate and display system info
get_system_identification() {
    {
        echo -e "\n\e[36mSystem Identification:\e[0m"
        echo

        # System Info
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Hostname:" "$(hostname)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Operating System:" "$(lsb_release -d | cut -f2)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Kernel Version:" "$(uname -r)"

        # CPU Info
        cpu_info=$(lscpu | grep 'Model name' | sed 's/Model name:[[:space:]]*//')
        cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
        printf "\e[36m%-18s\e[0m \e[32m%s (%s cores)\e[0m\n" "CPU Info:" "$cpu_info" "$cpu_cores"

        # GPU Info
        gpu_info=$(lspci | grep -i vga | sed 's/.*: //')
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "GPU Info:" "$gpu_info"

        # Memory Info
        total_mem=$(free -h | awk '/^Mem:/ {print $2}')
        used_mem=$(free -h | awk '/^Mem:/ {print $3}')
        printf "\e[36m%-18s\e[0m \e[32m%s / %s\e[0m\n" "Memory Info:" "$used_mem" "$total_mem"

        # Disk Info
        echo -e "\e[36mDisk Info:\e[0m"
        echo -e "\e[36mDrives:\e[0m"
        printf "\e[36m%-10s %-30s %-10s %-15s\e[0m\n" "Device" "Model" "Size" "Used"

        lsblk -d -o NAME,MODEL,SIZE | grep -v 'loop' | while read -r name model size; do
            used=$(df -h | grep "^/dev/${name}" | awk '{print $3}')
            if [[ -z "$used" ]]; then
                used="N/A"
            else
                # Check for different output formats
                if [[ "$used" =~ ^([0-9]+)G$ ]]; then
                    used=$((BASH_REMATCH[1] * 1024 ^ 3))
                elif [[ "$used" =~ ^[0-9]+M$ ]]; then
                    # Handle MB format
                    used=$((BASH_REMATCH[1] * 1024 ^ 2))
                fi
            fi
            printf "\e[32m%-10s %-30s %-10s %-15s\e[0m\n" "$name" "${model:0:30}" "$size" "$used"
        done

        # Network Info
        echo -e "\n\e[36mNetwork Info:\e[0m"
        ip -br addr show | grep -v '^lo' | while read -r iface ip; do
            printf "  \e[36m%-12s\e[0m \e[32m%s\e[0m\n" "$iface" "$ip"
        done

        echo
    }
    local exit_status=0
    exit_status=$? # Capture the exit status immediately
    if [ $exit_status -ne 0 ]; then
        handle_error "get_log_info" "$exit_status"
    fi
}

get_system_identification

perform_remote_update() {
    local update_steps=(
        "Updating remote package list:sudo -A apt-get update"
        "Upgrading remote packages:sudo -A apt-get upgrade -y"
        "Performing remote distribution upgrade:sudo -A apt-get dist-upgrade -y"
        "Removing unnecessary remote packages:sudo -A apt-get autoremove -y"
        "Cleaning up remote system:sudo -A apt-get clean"
    )
    for step in "${update_steps[@]}"; do
        IFS=':' read -r description command <<<"$step"
        echo
        log_message blue "$(printf '\e[3m%s\e[0m' "$description")"
        echo
        if [[ "$DRY_RUN" != "true" ]]; then
            if eval "$command" 2>&1 | tee -a "$LOG_FILE"; then
                log_message green "$description completed successfully!"
            else
                log_message red "Failed to $description"
                handle_error "perform_remote_update" "Failed to $description"
            fi
        else
            log_message yellow "[DRY RUN] Would run: $command"
        fi
    done
}

check_restart_required() {
    local exit_code=0

    # Use a compound command to group the code and catch errors
    {
        if [ -f /var/run/reboot-required ]; then
            log_message red "\nRemote Machine needs restarting\n"
            if [ -f /var/run/reboot-required.pkgs ]; then
                log_message blue "Packages requiring restart:"
                log_message blue "\n$(cat /var/run/reboot-required.pkgs)\n"
            fi
        else
            log_message blue "\nNo restart required\n"
        fi

        log_message blue "Time since last reboot:"
        log_message blue "\n$(uptime)\n"
    } || {
        exit_code=$?
        handle_error "check_restart_required" "Failed to check restart status: ${exit_code}"
    }
}

check_restart_required

# Check Unbound DNSSEC status with trimmed output and error handling
dnssec_query() {
    local result
    # Use dig with the necessary flags to reduce output and avoid hanging
    result=$(dig dnssec.works @pi.hole +dnssec +nocmd +noall +answer) || handle_error "dnssec_query" "Failed to query DNSSEC status." "dnssec_query"

    if [[ -z "$result" ]]; then
        handle_error "dnssec_query" "No valid DNSSEC response found." "dnssec_query"
    fi

    # Check if the result contains DNSSEC validation
    if echo "$result" | grep -q "RRSIG"; then
        echo "DNSSEC validation passed"
    else
        handle_error "dnssec_query" "DNSSEC validation failed." "dnssec_query"
    fi
}

# Call the function and store the result
dnssec_result=$(dnssec_query)

# Print the result if no error occurred
echo "DNSSEC result for dnssec.works: $dnssec_result"

# Main execution
main() {
    log_message blue "Starting $HostnameID update process"

    if validate_remote_environment; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_message yellow "Running in DRY RUN mode. No changes will be made."
        fi

        perform_remote_update

        # Check for errors
        if [ -s "$ERROR_LOG" ]; then
            log_message red "Errors were encountered during the script execution:"
            cat "$ERROR_LOG"
        else
            log_message green "<----[No errors detected during the $HostnameID script execution.]---->"
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log_message yellow "DRY RUN completed. No changes were made."
        else
            log_message cyan "         {{[[[**Completed, $HostnameID Script finished.**]]]}}"
        fi
    else
        log_message red "Validation of remote environment failed. Aborting update process."
        return 1
    fi
}

# Run main function
main

# Function to execute rsync with error handling
rsync_with_error_handling() {
  local source="$1"
  local destination="${2:-check}"

  # Execute rsync with -avz options and capture output
  rsync -avz "$source" "$destination" &> /tmp/rsync_output

  # Check for errors (non-zero exit code)
  if [[ $? -ne 0 ]]; then
    # Read captured output (assuming UTF-8 encoding)
    local error_message=$(cat /tmp/rsync_output | iconv -f UTF-8)
    echo "rsync command failed: $error_message"
    return 1  # Indicate error
  fi

  # Success message
  echo "rsync command successful: $source -> $destination"
  return 0  # Indicate success
}

source_path="/tmp/remote_update.log"
destination_path="/home/ageorge/Desktop/remote_update3.log"

rsync_with_error_handling "$source_path" "$destination_path"

if [[ $? -eq 0 ]]; then
  echo "Files synced successfully."
else
  echo "Sync failed. Please check the output for details."
fi


EOF

    # Set execute permissions on the remote script
    if ! chmod +x "$AG_Backup_local"; then
        log_message red "Error: Failed to set execute permissions on remote script"
        return 1
    fi

    log_message green "Remote script created at: $AG_Backup_local"
}

# Function to make Remote_Script2
create_remote_script2() {
    local available_space
    available_space=$(df -P "$(dirname "$pihole2_local")" | awk 'NR==2 {print $4}')

    # Check if available space is below a threshold (e.g., 1024 MB)
    if [[ $available_space -lt 1024 ]]; then
        echo "Insufficient disk space for remote script. Required: 1GB"
        exit 1
    fi

    # Writing the remote script content to file
    cat <<'EOF' >"$pihole2_local"
#!/bin/bash

# Initialize unset variables with defaults
AG_backup="${AG_backup:-192.168.1.238}"
BACKUP_DIR="${BACKUP_DIR:-/default/backup/dir}"
LOG_FILE="${LOG_FILE:-/default/log/file.log}"
REMOTE_USER="${REMOTE_USER:-ageorge}"
VERSION="${VERSION:-1.0.0}"
CHANGELOG_FILE="${CHANGELOG_FILE:-/default/changelog.txt}"
REMOTE_LOG="${REMOTE_LOG:-/default/remote_log.txt}"
RUN_LOG="${RUN_LOG:-/default/run_log.txt}"
LOCAL_UPDATE_ERROR="${LOCAL_UPDATE_ERROR:-/default/local_update_error.log}"
LOCAL_UPDATE_DEBUG="${LOCAL_UPDATE_DEBUG:-/default/local_update_debug.log}"
BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-/default/backup_log_dir}"
BACKUP_LOG_FILE="${BACKUP_LOG_FILE:-/default/backup_log_file.log}"


# Enable error trapping
set -o errexit # Enable strict error checking
#set -o nounset # Exit if an unset variable is used
set -o noglob # Disable filename expansion
set -eE

handle_error() {
    local func_name="$1"
    local err="${2:-check}"
    local retry_command="$3"
    local retry_count=0
    local max_retries=3
    local backtrace_file="/tmp/error_backtrace.txt"

    # Log the error message
    log_message red "Error in function '${func_name}': ${err}"

    # Write the error to a specific error log file
    echo "Error in function '${func_name}': ${err}" >>"$LOCAL_UPDATE_ERROR"

    # Generate backtrace
    echo "Backtrace:" >>"$backtrace_file"
    local i=0
    while caller $i >>"$backtrace_file"; do
        ((i++))
    done

    # Temporarily disable errexit
    set +e

    # Implement retry logic
    while [[ $retry_count -lt $max_retries ]]; do
        log_message yellow "Retrying after error... Attempt $((retry_count + 1))/$max_retries"

        # Retry the failed operation
        if eval "$retry_command"; then
            log_message green "Retried successfully on attempt $((retry_count + 1))"
            return 0
        fi

        # Increase the retry count
        ((retry_count++))

        # Optional: Add a delay between retries (e.g., 5 seconds)
        sleep 5
    done

    # Re-enable errexit
    set -e

    # If all retries fail, log the failure, print the backtrace, and exit the script
    log_message red "All retries failed. Exiting script."
    cat "$backtrace_file"
    exit 1
}


# Trap errors and signals
trap 'handle_error "$BASH_COMMAND" "$?"' ERR
trap 'echo "Script terminated prematurely" >> "$RUN_LOG"; exit 1' SIGINT SIGTERM
trap 'handle_error "SIGPIPE received" "$?"' SIGPIPE

VERSION="1.2 (PiHole2)"
LOG_FILE="/tmp/remote_update.log"
BACKUP_LOG_DIR="$HOME/Desktop"
BACKUP_LOG_FILE="$BACKUP_LOG_DIR/remote_update2.log"
SUDO_ASKPASS_PATH="$HOME/sudo_askpass.sh"
RUN_LOG="/tmp/remote_run_log.txt"
ERROR_LOG="/tmp/remote_error_log.txt"
REMOTE_SCRIPT_LOCAL2="/tmp/remote_update2.sh"
# shellcheck disable=SC2269
DRY_RUN="$DRY_RUN" # Pass DRY_RUN from the main script
HostnameID="pihole2.home"

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
    *) color_code="" ;;
    esac
    echo -e "${color_code}${message}\e[0m" | tee -a "$LOG_FILE"
}

# Export SUDO_ASKPASS
export SUDO_ASKPASS="$SUDO_ASKPASS_PATH"

# Initialize RUN_LOG and ERROR_LOG
true >"$RUN_LOG"
true >"$ERROR_LOG"

# Validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a ip_parts <<<"$ip"
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

verify_and_create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_message yellow "Directory $dir does not exist. Creating it..."
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! mkdir -p "$dir"; then
                handle_error "verify_and_create_directory" "Failed to create directory: $dir"
            fi
        else
            log_message yellow "[DRY RUN] Would create directory: $dir"
        fi
    fi
    if [[ ! -w "$dir" && "$DRY_RUN" != "true" ]]; then
        handle_error "verify_and_create_directory" "Cannot write to directory: $dir"
    fi
}

verify_file_path() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    if ! verify_and_create_directory "$dir"; then
        handle_error "verify_file_path" "Failed to verify/create directory for file: $file"
    fi
    if [[ ! -f "$file" && "${2:-check}" != "create" ]]; then
        handle_error "verify_file_path" "File does not exist: $file"
    fi
    if [[ "${2:-check}" == "create" && ! -f "$file" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! touch "$file"; then
                handle_error "verify_file_path" "Failed to create file: $file"
            fi
        else
            log_message yellow "[DRY RUN] Would create file: $file"
        fi
    fi
    if [[ ! -w "$file" && "$DRY_RUN" != "true" ]]; then
        handle_error "verify_file_path" "Cannot write to file: $file"
    fi
}

# Validation checks
validate_remote_environment() {
    if [[ -z "$VERSION" ]]; then
        handle_error "validate_remote_environment" "VERSION is not set"
    fi

    # Verify and create necessary directories and files
    verify_file_path "$SUDO_ASKPASS_PATH" || return 1
    verify_file_path "$RUN_LOG" "create" || return 1
    verify_file_path "$ERROR_LOG" "create" || return 1
    verify_file_path "$REMOTE_SCRIPT_LOCAL2" "create" || return 1

    # Check for required commands
    local required_commands=("ssh" "scp" "md5sum" "sudo" "apt-get")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            handle_error "validate_remote_environment" "Required command not found: $cmd"
        fi
    done

    return 0
}

# Function to generate and display system info
get_system_identification() {
    {
        echo -e "\n\e[36mSystem Identification:\e[0m"
        echo

        # System Info
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Hostname:" "$(hostname)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Operating System:" "$(lsb_release -d | cut -f2)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Kernel Version:" "$(uname -r)"

        # CPU Info
        cpu_info=$(lscpu | grep 'Model name' | sed 's/Model name:[[:space:]]*//')
        cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
        printf "\e[36m%-18s\e[0m \e[32m%s (%s cores)\e[0m\n" "CPU Info:" "$cpu_info" "$cpu_cores"

        # GPU Info
        gpu_info=$(lspci | grep -i vga | sed 's/.*: //')
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "GPU Info:" "$gpu_info"

        # Memory Info
        total_mem=$(free -h | awk '/^Mem:/ {print $2}')
        used_mem=$(free -h | awk '/^Mem:/ {print $3}')
        printf "\e[36m%-18s\e[0m \e[32m%s / %s\e[0m\n" "Memory Info:" "$used_mem" "$total_mem"

        # Disk Info
        echo -e "\e[36mDisk Info:\e[0m"
        echo -e "\e[36mDrives:\e[0m"
        printf "\e[36m%-10s %-30s %-10s %-15s\e[0m\n" "Device" "Model" "Size" "Used"

        lsblk -d -o NAME,MODEL,SIZE | grep -v 'loop' | while read -r name model size; do
            used=$(df -h | grep "^/dev/${name}" | awk '{print $3}')
            if [[ -z "$used" ]]; then
                used="N/A"
            else
                # Check for different output formats
                if [[ "$used" =~ ^([0-9]+)G$ ]]; then
                    used=$((BASH_REMATCH[1] * 1024 ^ 3))
                elif [[ "$used" =~ ^[0-9]+M$ ]]; then
                    # Handle MB format
                    used=$((BASH_REMATCH[1] * 1024 ^ 2))
                fi
            fi
            printf "\e[32m%-10s %-30s %-10s %-15s\e[0m\n" "$name" "${model:0:30}" "$size" "$used"
        done

        # Network Info
        echo -e "\n\e[36mNetwork Info:\e[0m"
        ip -br addr show | grep -v '^lo' | while read -r iface ip; do
            printf "  \e[36m%-12s\e[0m \e[32m%s\e[0m\n" "$iface" "$ip"
        done

        echo
    }
    local exit_status=0
    exit_status=$? # Capture the exit status immediately
    if [ $exit_status -ne 0 ]; then
        handle_error "get_log_info" "$exit_status"
    fi
}

get_system_identification

perform_remote_update() {
    local update_steps=(
        "Updating remote package list:sudo -A apt-get update"
        "Upgrading remote packages:sudo -A apt-get upgrade -y"
        "Performing remote distribution upgrade:sudo -A apt-get dist-upgrade -y"
        "Removing unnecessary remote packages:sudo -A apt-get autoremove -y"
        "Cleaning up remote system:sudo -A apt-get clean"
    )
    for step in "${update_steps[@]}"; do
        IFS=':' read -r description command <<<"$step"
        echo
        log_message blue "$(printf '\e[3m%s\e[0m' "$description")"
        echo
        if [[ "$DRY_RUN" != "true" ]]; then
            if eval "$command" 2>&1 | tee -a "$LOG_FILE"; then
                log_message green "$description completed successfully!"
            else
                log_message red "Failed to $description"
                handle_error "perform_remote_update" "Failed to $description"
            fi
        else
            log_message yellow "[DRY RUN] Would run: $command"
        fi
    done
}

check_restart_required() {
    local exit_code=0

    # Use a compound command to group the code and catch errors
    {
        if [ -f /var/run/reboot-required ]; then
            log_message red "\nRemote Machine needs restarting\n"
            if [ -f /var/run/reboot-required.pkgs ]; then
                log_message blue "Packages requiring restart:"
                log_message blue "\n$(cat /var/run/reboot-required.pkgs)\n"
            fi
        else
            log_message blue "\nNo restart required\n"
        fi

        log_message blue "Time since last reboot:"
        log_message blue "\n$(uptime)\n"
    } || {
        exit_code=$?
        handle_error "check_restart_required" "Failed to check restart status: ${exit_code}"
    }
}

check_restart_required

# Check Unbound DNSSEC status with trimmed output and error handling
dnssec_query() {
    local result
    # Use dig with the necessary flags to reduce output and avoid hanging
    result=$(dig dnssec.works @pi.hole +dnssec +nocmd +noall +answer) || handle_error "dnssec_query" "Failed to query DNSSEC status." "dnssec_query"

    if [[ -z "$result" ]]; then
        handle_error "dnssec_query" "No valid DNSSEC response found." "dnssec_query"
    fi

    # Check if the result contains DNSSEC validation
    if echo "$result" | grep -q "RRSIG"; then
        echo "DNSSEC validation passed"
    else
        handle_error "dnssec_query" "DNSSEC validation failed." "dnssec_query"
    fi
}

# Call the function and store the result
dnssec_result=$(dnssec_query)

# Print the result if no error occurred
echo "DNSSEC result for dnssec.works: $dnssec_result"

# Main execution
main() {
    log_message blue "Starting $HostnameID update process"

    if validate_remote_environment; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_message yellow "Running in DRY RUN mode. No changes will be made."
        fi

        perform_remote_update

        # Check for errors
        if [ -s "$ERROR_LOG" ]; then
            log_message red "Errors were encountered during the script execution:"
            cat "$ERROR_LOG"
        else
            log_message green "<----[No errors detected during the $HostnameID script execution.]---->"
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log_message yellow "DRY RUN completed. No changes were made."
        else
            log_message cyan "         {{[[[**Completed, $HostnameID Script finished.**]]]}}"
        fi
    else
        log_message red "Validation of remote environment failed. Aborting update process."
        return 1
    fi
}

# Run main function
main

# Function to execute rsync with error handling
rsync_with_error_handling() {
  local source="$1"
  local destination="${2:-check}"

  # Execute rsync with -avz options and capture output
  rsync -avz "$source" "$destination" &> /tmp/rsync_output

  # Check for errors (non-zero exit code)
  if [[ $? -ne 0 ]]; then
    # Read captured output (assuming UTF-8 encoding)
    local error_message=$(cat /tmp/rsync_output | iconv -f UTF-8)
    echo "rsync command failed: $error_message"
    return 1  # Indicate error
  fi

  # Success message
  echo "rsync command successful: $source -> $destination"
  return 0  # Indicate success
}

source_path="/tmp/remote_update.log"
destination_path="/home/ageorge/Desktop/remote_update2.log"

rsync_with_error_handling "$source_path" "$destination_path"

if [[ $? -eq 0 ]]; then
  echo "Files synced successfully."
else
  echo "Sync failed. Please check the output for details."
fi

EOF

    # Set execute permissions on the remote script
    if ! chmod +x "$pihole2_local"; then
        log_message red "Error: Failed to set execute permissions on remote script"
        return 1
    fi

    log_message green "Remote script created at: $pihole2_local"
}

# Function to make Remote_Script
create_remote_script() {
    local available_space
    available_space=$(df -P "$(dirname "$pihole_local")" | awk 'NR==2 {print $4}')

    # Check if available space is below a threshold (e.g., 1024 MB)
    if [[ $available_space -lt 1024 ]]; then
        echo "Insufficient disk space for remote script. Required: 1GB"
        exit 1
    fi

    # Writing the remote script content to file
    cat <<'EOF' >"$pihole_local"
#!/bin/bash

# Initialize unset variables with defaults
AG_backup="${AG_backup:-192.168.1.238}"
BACKUP_DIR="${BACKUP_DIR:-/default/backup/dir}"
LOG_FILE="${LOG_FILE:-/default/log/file.log}"
REMOTE_USER="${REMOTE_USER:-ageorge}"
VERSION="${VERSION:-1.0.0}"
CHANGELOG_FILE="${CHANGELOG_FILE:-/default/changelog.txt}"
REMOTE_LOG="${REMOTE_LOG:-/default/remote_log.txt}"
RUN_LOG="${RUN_LOG:-/default/run_log.txt}"
LOCAL_UPDATE_ERROR="${LOCAL_UPDATE_ERROR:-/default/local_update_error.log}"
LOCAL_UPDATE_DEBUG="${LOCAL_UPDATE_DEBUG:-/default/local_update_debug.log}"
BACKUP_LOG_DIR="${BACKUP_LOG_DIR:-/default/backup_log_dir}"
BACKUP_LOG_FILE="${BACKUP_LOG_FILE:-/default/backup_log_file.log}"


# Enable error trapping
set -o errexit # Enable strict error checking
#set -o nounset # Exit if an unset variable is used
set -o noglob # Disable filename expansion
set -eE

handle_error() {
    local func_name="$1"
    local err="${2:-check}"
    local retry_command="$3"
    local retry_count=0
    local max_retries=3
    local backtrace_file="/tmp/error_backtrace.txt"

    # Log the error message
    log_message red "Error in function '${func_name}': ${err}"

    # Write the error to a specific error log file
    echo "Error in function '${func_name}': ${err}" >>"$LOCAL_UPDATE_ERROR"

    # Generate backtrace
    echo "Backtrace:" >>"$backtrace_file"
    local i=0
    while caller $i >>"$backtrace_file"; do
        ((i++))
    done

    # Temporarily disable errexit
    set +e

    # Implement retry logic
    while [[ $retry_count -lt $max_retries ]]; do
        log_message yellow "Retrying after error... Attempt $((retry_count + 1))/$max_retries"

        # Retry the failed operation
        if eval "$retry_command"; then
            log_message green "Retried successfully on attempt $((retry_count + 1))"
            return 0
        fi

        # Increase the retry count
        ((retry_count++))

        # Optional: Add a delay between retries (e.g., 5 seconds)
        sleep 5
    done

    # Re-enable errexit
    set -e

    # If all retries fail, log the failure, print the backtrace, and exit the script
    log_message red "All retries failed. Exiting script."
    cat "$backtrace_file"
    exit 1
}


# Trap errors and signals
trap 'handle_error "$BASH_COMMAND" "$?"' ERR
trap 'echo "Script terminated prematurely" >> "$RUN_LOG"; exit 1' SIGINT SIGTERM
trap 'handle_error "SIGPIPE received" "$?"' SIGPIPE

VERSION="1.2 (pihole.main)"
LOG_FILE="/tmp/remote_update.log"
SUMMARY_LOG="/tmp/remote_update_summary.log"
BACKUP_LOG_DIR="$HOME/Desktop"
BACKUP_LOG_FILE="$BACKUP_LOG_DIR/remote_update.log"
SUDO_ASKPASS_PATH="$HOME/sudo_askpass.sh"
RUN_LOG="/tmp/remote_run_log.txt"
ERROR_LOG="/tmp/remote_error_log.txt"
# shellcheck disable=SC2269
DRY_RUN="$DRY_RUN" # Pass DRY_RUN from the main script

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
    *) color_code="" ;;
    esac
    echo -e "${color_code}${message}\e[0m" | tee -a "$LOG_FILE"
}

# Export SUDO_ASKPASS
export SUDO_ASKPASS="$SUDO_ASKPASS_PATH"

# Initialize RUN_LOG and ERROR_LOG
true >"$RUN_LOG"
true >"$ERROR_LOG"

# Validation functions
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a ip_parts <<<"$ip"
        for part in "${ip_parts[@]}"; do
            if [[ $part -gt 255 ]]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

verify_and_create_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_message yellow "Directory $dir does not exist. Creating it..."
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! mkdir -p "$dir"; then
                handle_error "verify_and_create_directory" "Failed to create directory: $dir"
            fi
        else
            log_message yellow "[DRY RUN] Would create directory: $dir"
        fi
    fi
    if [[ ! -w "$dir" && "$DRY_RUN" != "true" ]]; then
        handle_error "verify_and_create_directory" "Cannot write to directory: $dir"
    fi
}

verify_file_path() {
    local file="$1"
    local dir
    dir=$(dirname "$file")
    if ! verify_and_create_directory "$dir"; then
        handle_error "verify_file_path" "Failed to verify/create directory for file: $file"
    fi
    if [[ ! -f "$file" && "${2:-check}" != "create" ]]; then
        handle_error "verify_file_path" "File does not exist: $file"
    fi
    if [[ "${2:-check}" == "create" && ! -f "$file" ]]; then
        if [[ "$DRY_RUN" != "true" ]]; then
            if ! touch "$file"; then
                handle_error "verify_file_path" "Failed to create file: $file"
            fi
        else
            log_message yellow "[DRY RUN] Would create file: $file"
        fi
    fi
    if [[ ! -w "$file" && "$DRY_RUN" != "true" ]]; then
        handle_error "verify_file_path" "Cannot write to file: $file"
    fi
}

# Validation checks
validate_remote_environment() {
    if [[ -z "$VERSION" ]]; then
        handle_error "validate_remote_environment" "VERSION is not set"
    fi

    # Verify and create necessary directories and files
    verify_file_path "$SUDO_ASKPASS_PATH" || return 1
    verify_file_path "$RUN_LOG" "create" || return 1
    verify_file_path "$ERROR_LOG" "create" || return 1

    # Check for required commands
    local required_commands=("ssh" "scp" "md5sum" "sudo" "apt-get" "pihole")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            handle_error "validate_remote_environment" "Required command not found: $cmd"
        fi
    done

    return 0
}

# Function to generate and display system info
get_system_identification() {
    {
        echo -e "\n\e[36mSystem Identification:\e[0m"
        echo

        # System Info
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Hostname:" "$(hostname)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Operating System:" "$(lsb_release -d | cut -f2)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Kernel Version:" "$(uname -r)"

        # CPU Info
        cpu_info=$(lscpu | grep 'Model name' | sed 's/Model name:[[:space:]]*//')
        cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
        printf "\e[36m%-18s\e[0m \e[32m%s (%s cores)\e[0m\n" "CPU Info:" "$cpu_info" "$cpu_cores"

        # GPU Info
        gpu_info=$(lspci | grep -i vga | sed 's/.*: //')
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "GPU Info:" "$gpu_info"

        # Memory Info
        total_mem=$(free -h | awk '/^Mem:/ {print $2}')
        used_mem=$(free -h | awk '/^Mem:/ {print $3}')
        printf "\e[36m%-18s\e[0m \e[32m%s / %s\e[0m\n" "Memory Info:" "$used_mem" "$total_mem"

        # Disk Info
        echo -e "\e[36mDisk Info:\e[0m"
        echo -e "\e[36mDrives:\e[0m"
        printf "\e[36m%-10s %-30s %-10s %-15s\e[0m\n" "Device" "Model" "Size" "Used"

        lsblk -d -o NAME,MODEL,SIZE | grep -v 'loop' | while read -r name model size; do
            used=$(df -h | grep "^/dev/${name}" | awk '{print $3}')
            if [[ -z "$used" ]]; then
                used="N/A"
            else
                # Check for different output formats
                if [[ "$used" =~ ^([0-9]+)G$ ]]; then
                    used=$((BASH_REMATCH[1] * 1024 ^ 3))
                elif [[ "$used" =~ ^[0-9]+M$ ]]; then
                    # Handle MB format
                    used=$((BASH_REMATCH[1] * 1024 ^ 2))
                fi
            fi
            printf "\e[32m%-10s %-30s %-10s %-15s\e[0m\n" "$name" "${model:0:30}" "$size" "$used"
        done

        # Network Info
        echo -e "\n\e[36mNetwork Info:\e[0m"
        ip -br addr show | grep -v '^lo' | while read -r iface ip; do
            printf "  \e[36m%-12s\e[0m \e[32m%s\e[0m\n" "$iface" "$ip"
        done

        echo
    }
    local exit_status=0
    exit_status=$? # Capture the exit status immediately
    if [ $exit_status -ne 0 ]; then
        handle_error "get_log_info" "$exit_status"
    fi
}

get_system_identification

perform_remote_update() {
    local update_steps=(
        "Updating remote package list:sudo -A apt-get update"
        "Upgrading remote packages:sudo -A apt-get upgrade -y"
        "Performing remote distribution upgrade:sudo -A apt-get dist-upgrade -y"
        "Removing unnecessary remote packages:sudo -A apt-get autoremove -y"
        "Cleaning up remote system:sudo -A apt-get clean"
        "Updating Pi-hole:sudo -A pihole -up"
        "Updating Pi-hole gravity:sudo -A pihole -g > /tmp/pihole_gravity.log 2>&1"
    )

    # Verify pihole_gravity.log path
    verify_file_path "/tmp/pihole_gravity.log" "create" || return 1

    for step in "${update_steps[@]}"; do
        IFS=':' read -r description command <<<"$step"
        echo

        # Log the start of the update step in blue
        log_message blue "$(printf '\e[3m%s\e[0m' "$description")"

        if [[ "$DRY_RUN" != "true" ]]; then
            if [[ "$description" == "Updating Pi-hole gravity" ]]; then
                # Start the command in the background
                eval "$command" &
                pid=$!

                # Display a spinning progress indicator
                spin='-\|/'
                i=0
                while kill -0 $pid 2>/dev/null; do
                    i=$(((i + 1) % 4))
                    printf "\r[%c] Updating Pi-hole gravity..." "${spin:$i:1}"
                    sleep .1
                done
                # Log the success of the update in green
                log_message green "Pi-hole gravity update completed successfully!"
            else
                # Execute the command and log the result
                if ! eval "$command" 2>&1 | tee -a "$LOG_FILE"; then
                    handle_error "perform_remote_update" "Failed to $description"
                else
                    # Log the success of the update in green
                    log_message green "$description completed successfully!"
                fi
            fi
        else
            log_message yellow "[DRY RUN] Would run: $command"
        fi
    done

    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ -f /tmp/pihole_gravity.log ]] && grep -q "FTL is listening" /tmp/pihole_gravity.log; then
            log_message green "Pi-hole gravity update completed successfully!"
            echo
        else
            echo -e "Pi-hole gravity update encountered an issue" >>"$SUMMARY_LOG"
            handle_error "perform_remote_update" "Pi-hole gravity update encountered an issue. Check /tmp/pihole_gravity.log for details."
        fi
    fi
}

check_restart_required() {
    local exit_code=0

    # Use a compound command to group the code and catch errors
    {
        if [ -f /var/run/reboot-required ]; then
            log_message red "\nRemote Machine needs restarting\n"
            if [ -f /var/run/reboot-required.pkgs ]; then
                log_message blue "Packages requiring restart:"
                log_message blue "\n$(cat /var/run/reboot-required.pkgs)\n"
            fi
        else
            log_message blue "\nNo restart required\n"
        fi

        log_message blue "Time since last reboot:"
        log_message blue "\n$(uptime)\n"
    } || {
        exit_code=$?
        handle_error "check_restart_required" "Failed to check restart status: ${exit_code}"
    }
}

check_restart_required

# Check unbound status
log_message blue "Checking unbound status"
if [[ "$DRY_RUN" != "true" ]]; then
    if ! sudo -A netstat -tulpen | grep ':5335' | tee -a "$LOG_FILE"; then
        handle_error "perform_remote_update" "Failed to check unbound status"
    fi
else
    log_message yellow "[DRY RUN] Would run: sudo netstat -tulpen | grep ':5335'"
fi

# Main execution
main() {
    log_message blue "Starting Pi_Hole update process"

    if validate_remote_environment; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log_message yellow "Running in DRY RUN mode. No changes will be made."
        fi

        perform_remote_update

        # Check for errors
        if [ -s "$ERROR_LOG" ]; then
            log_message red "Errors were encountered during the script execution:"
            cat "$ERROR_LOG"
        else
            log_message green "<----[No errors detected during the Remote Pi-Hole script execution.]---->"
        fi

        if [[ "$DRY_RUN" == "true" ]]; then
            log_message yellow "DRY RUN completed. No changes were made."
        else
            log_message cyan "         {{[[[**Completed, Pi-Hole finished.**]]]}}"
        fi
    else
        log_message red "Validation of Pi-Hole environment failed. Aborting update process."
        return 1
    fi
}

# Run main function
main

# Function to execute rsync with error handling
rsync_with_error_handling() {
  local source="$1"
  local destination="${2:-check}"

  # Execute rsync with -avz options and capture output
  rsync -avz "$source" "$destination" &> /tmp/rsync_output

  # Check for errors (non-zero exit code)
  if [[ $? -ne 0 ]]; then
    # Read captured output (assuming UTF-8 encoding)
    local error_message=$(cat /tmp/rsync_output | iconv -f UTF-8)
    echo "rsync command failed: $error_message"
    return 1  # Indicate error
  fi

  # Success message
  echo "rsync command successful: $source -> $destination"
  return 0  # Indicate success
}

source_path="/tmp/remote_update.log"
destination_path="/home/ageorge/Desktop/remote_update.log"

rsync_with_error_handling "$source_path" "$destination_path"

if [[ $? -eq 0 ]]; then
  echo "Files synced successfully."
else
  echo "Sync failed. Please check the output for details."
fi

EOF

    # Set execute permissions on the remote script
    if ! chmod +x "$pihole_local"; then
        log_message red "Error: Failed to set execute permissions on remote script"
        return 1
    fi

    log_message green "Remote script created at: $pihole_local"
}

# Invoke remote script creation
create_remote_script
create_remote_script2
create_remote_script3

# Define the correct checksum file names for each script
LOCAL_CHECKSUM_FILE_REMOTE1="/tmp/remote_update.sh.md5"
LOCAL_CHECKSUM_FILE_REMOTE2="/tmp/remote_update2.sh.md5"
LOCAL_CHECKSUM_FILE_REMOTE3="/tmp/remote_update3.sh.md5"

# Function to generate local checksums with correct file naming
generate_local_checksums() {
    echo "Generating local checksums..."

    if ! md5sum "$pihole_local" >"$LOCAL_CHECKSUM_FILE_REMOTE1"; then
        log_message red "Failed to generate local checksum for $pihole_local"
        return 1
    fi

    if ! md5sum "$pihole2_local" >"$LOCAL_CHECKSUM_FILE_REMOTE2"; then
        log_message red "Failed to generate local checksum for $pihole2_local"
        return 1
    fi

    if ! md5sum "$AG_Backup_local" >"$LOCAL_CHECKSUM_FILE_REMOTE3"; then
        log_message red "Failed to generate local checksum for $AG_Backup_local"
        return 1
    fi

    log_message green "Local checksums generated successfully."
}

# shellcheck disable=SC2029
# Function to copy script to remote, set permissions, and generate remote checksum
copy_local_to_remote() {
    if check_dry_run_mode; then
        echo "scp $pihole_local $REMOTE_USER@$pihole:$pihole_Remote"
        echo "ssh $REMOTE_USER@$pihole 'chmod +x $pihole_Remote'"
        echo "ssh $REMOTE_USER@$pihole 'md5sum $pihole_Remote > /tmp/remote_update.sh.md5'"
    else
        echo "Copying and generating checksum for remote_update.sh on $pihole..."
        if ! scp "$pihole_local" "$REMOTE_USER@$pihole:$pihole_Remote"; then
            handle_error "copy_local_to_remote" "Failed to copy script to remote host"
        fi
        if ! ssh "$REMOTE_USER@$pihole" "chmod +x '$pihole_Remote'"; then
            handle_error "copy_local_to_remote" "Failed to set execute permissions on remote script"
        fi
        if ! ssh "$REMOTE_USER@$pihole" "md5sum '$pihole_Remote' > /tmp/remote_update.sh.md5"; then
            handle_error "copy_local_to_remote" "Failed to generate remote checksum"
        fi
    fi
}
# shellcheck disable=SC2029
copy_local_to_remote2() {
    if check_dry_run_mode; then
        echo "scp $pihole2_local $REMOTE_USER@$pihole2:$pihole2_Remote"
        echo "ssh $REMOTE_USER@$pihole2 'chmod +x $pihole2_Remote'"
        echo "ssh $REMOTE_USER@$pihole2 'md5sum $pihole2_Remote > /tmp/remote_update2.sh.md5'"
    else
        echo "Copying and generating checksum for remote_update2.sh on $pihole2..."
        if ! scp "$pihole2_local" "$REMOTE_USER@$pihole2:$pihole2_Remote"; then
            handle_error "copy_local_to_remote2" "Failed to copy script to remote host2"
        fi
        if ! ssh "$REMOTE_USER@$pihole2" "chmod +x '$pihole2_Remote'"; then
            handle_error "copy_local_to_remote2" "Failed to set execute permissions on remote script2"
        fi
        if ! ssh "$REMOTE_USER@$pihole2" "md5sum '$pihole2_Remote' > /tmp/remote_update2.sh.md5"; then
            echo "Debug: Failed to generate checksum on $pihole2 for $pihole2_Remote"
            handle_error "copy_local_to_remote2" "Failed to generate remote checksum on host2"
        else
            echo "Checksum generated for remote_update2.sh on $pihole2"
        fi
    fi
}
# shellcheck disable=SC2029
copy_local_to_remote3() {
    if check_dry_run_mode; then
        echo "scp $AG_Backup_local $REMOTE_USER@$AG_backup:$AG_Backup_Remote"
        echo "ssh $REMOTE_USER@$AG_backup 'chmod +x $AG_Backup_Remote'"
        echo "ssh $REMOTE_USER@$AG_backup 'md5sum $AG_Backup_Remote > /tmp/remote_update3.sh.md5'"
    else
        echo "Copying and generating checksum for remote_update3.sh on $AG_backup..."
        if ! scp "$AG_Backup_local" "$REMOTE_USER@$AG_backup:$AG_Backup_Remote"; then
            handle_error "copy_local_to_remote3" "Failed to copy script to remote host3"
        fi
        if ! ssh "$REMOTE_USER@$AG_backup" "chmod +x '$AG_Backup_Remote'"; then
            handle_error "copy_local_to_remote3" "Failed to set execute permissions on remote script3"
        fi
        if ! ssh "$REMOTE_USER@$AG_backup" "md5sum '$AG_Backup_Remote' > /tmp/remote_update3.sh.md5"; then
            echo "Debug: Failed to generate checksum on $AG_backup for $AG_Backup_Remote"
            handle_error "copy_local_to_remote3" "Failed to generate remote checksum on host3"
        else
            echo "Checksum generated for remote_update3.sh on $AG_backup"
        fi
    fi
}
# shellcheck disable=SC2029
# Function to verify remote checksums
verify_checksums() {
    log_message light_blue "Verifying script checksums on remote servers..."

    # Checksum verification for remote_update.sh
    if scp "$REMOTE_USER@$pihole:/tmp/remote_update.sh.md5" /tmp/; then
        if diff -q "$LOCAL_CHECKSUM_FILE_REMOTE1" /tmp/remote_update.sh.md5; then
            log_message light_magenta "Checksum verification successful for remote_update.sh.md5: Checksums match."
        else
            log_message red "Checksum verification failed for remote_update.sh.md5: Checksums do not match."
        fi
    else
        log_message red "Failed to retrieve remote checksum file: remote_update.sh.md5"
    fi

    # Checksum verification for remote_update2.sh
    if scp "$REMOTE_USER@$pihole2:/tmp/remote_update2.sh.md5" /tmp/; then
        if diff -q "$LOCAL_CHECKSUM_FILE_REMOTE2" /tmp/remote_update2.sh.md5; then
            log_message light_magenta "Checksum verification successful for remote_update2.sh.md5: Checksums match."
        else
            log_message red "Checksum verification failed for remote_update2.sh.md5: Checksums do not match."
        fi
    else
        log_message red "Failed to retrieve remote checksum file: remote_update2.sh.md5"
        ssh "$REMOTE_USER@$pihole2" "ls -l /tmp/remote_update2.sh.md5"
    fi

    # Checksum verification for remote_update3.sh
    if scp "$REMOTE_USER@$AG_backup:/tmp/remote_update3.sh.md5" /tmp/; then
        if diff -q "$LOCAL_CHECKSUM_FILE_REMOTE3" /tmp/remote_update3.sh.md5; then
            log_message light_magenta "Checksum verification successful for remote_update3.sh.md5: Checksums match."
        else
            log_message red "Checksum verification failed for remote_update3.sh.md5: Checksums do not match."
        fi
    else
        log_message red "Failed to retrieve remote checksum file: remote_update3.sh.md5"
        ssh "$REMOTE_USER@$AG_backup" "ls -l /tmp/remote_update3.sh.md5"
    fi
}

# Main execution steps remain the same
generate_local_checksums
copy_local_to_remote
copy_local_to_remote2
copy_local_to_remote3
verify_checksums

# shellcheck disable=SC2029
# Log Information Function
get_log_info2() {
    {
        echo -e "\n\e[36mLog Information:\e[0m"
        local_logs=()
        remote_logs=()
        local logs=(
            "$LOG_FILE:Local Update Log:local"
            "$pihole_Remote:Remote Update Script (Remote):remote"
            "/var/log/pihole/pihole_updateGravity.log:Pi-hole Gravity Update Log:remote"
            "/var/log/pihole/FTL.log:Pi-hole FTL Log:remote"
            "/var/log/pihole/pihole.log:Pi-hole Log:remote"
            "/var/log/auth.log:Auth Log:local"
            "/var/log/boot.log:Boot Log:local"
            "/var/log/dpkg.log:DPKG Log:local"
            "/var/log/fail2ban.log:Fail2Ban Log:local"
            "/var/log/gpu-manager.log:GPU Manager Log:local"
            "/var/log/kern.log:Kernel Log:local"
            "/var/log/mintsystem.log:Mint System Log:local"
            "/var/log/syslog:System Log:local"
            "$LOCAL_UPDATE_ERROR:Local Error Log:local"
            "$LOCAL_UPDATE_DEBUG:Local Debug Log:local"
            "/var/log/auth.log:Auth Log:remote"         # Added for remote
            "/var/log/boot.log:Boot Log:remote"         # Added for remote
            "/var/log/dpkg.log:DPKG Log:remote"         # Added for remote
            "/var/log/fail2ban.log:Fail2Ban Log:remote" # Added for remote
            "/var/log/kern.log:Kernel Log:remote"       # Added for remote
            "/var/log/syslog:System Log:remote"         # Added for remote
        )

        for log in "${logs[@]}"; do
            IFS=':' read -r path name location <<<"$log"
            if [ "$location" = "local" ]; then
                if [ -f "$path" ]; then
                    log_size=$(du -h "$path" | cut -f1)
                    local_logs+=("✓ $name:$log_size")
                else
                    local_logs+=("✗ $name:Not Found")
                fi
            else
                remote_log=$(ssh "$REMOTE_USER@$pihole" "test -f $path && du -h $path || echo 'Not Found'")
                if [[ $remote_log == *"Not Found"* ]]; then
                    remote_logs+=("✗ $name:Not Found")
                else
                    log_size=$(echo "$remote_log" | cut -f1)
                    remote_logs+=("✓ $name:$log_size")
                fi
            fi
        done

        # Print the logs side by side
        max_lines=$((${#local_logs[@]} > ${#remote_logs[@]} ? ${#local_logs[@]} : ${#remote_logs[@]}))

        printf "\e[36m%-36s %-10s  \e[36m%-36s %-10s\e[0m\n" "Local Logs:" "Size:" "Remote Logs:" "Size:"
        for ((i = 0; i < max_lines; i++)); do
            local_log=${local_logs[i]:-""}
            remote_log=${remote_logs[i]:-""}

            local_name=$(echo "$local_log" | cut -d':' -f1)
            local_size=$(echo "$local_log" | cut -d':' -f2)

            remote_name=$(echo "$remote_log" | cut -d':' -f1)
            remote_size=$(echo "$remote_log" | cut -d':' -f2)

            printf "   \e[32m%-36s\e[0m : \e[32m%-10s\e[0m  \e[32m%-36s\e[0m : \e[32m%-10s\e[0m\n" "$local_name" "$local_size" "$remote_name" "$remote_size"
        done

        echo -e "\n"
    }
    local exit_status=0
    exit_status=$? # Capture the exit status immediately
    if [ $exit_status -ne 0 ]; then
        handle_error "get_log_info" "$exit_status"
    fi
}

# Function to check the RUN_LOG for errors
check_run_log() {
    {
        if [ -s "$RUN_LOG" ]; then
            log_message red "Errors were encountered during the script execution:"
            cat "$RUN_LOG"
            true >"$RUN_LOG" # Clear the RUN_LOG after displaying errors
        else
            log_message green "<----[No errors detected during the Local script execution.]---->"
        fi
    } || handle_error "check_run_log" "$?"
}

# Function to ensure checksum utility is available
ensure_checksum_utility() {
    {
        if ! command -v md5sum &>/dev/null; then
            log_message red "md5sum is not installed. Please install it and try again."
            exit 1
        fi
    } || handle_error "ensure_checksum_utility" "$?"
}

# Announce the version
log_message cyan "Starting script version $VERSION"

# Backup log file if it exists
if [ -f "$LOG_FILE" ]; then
    {
        log_message yellow "Backing up existing log file..."
        cat "$LOG_FILE" >>"$BACKUP_LOG_FILE"
    } || handle_error "backup_log_file" "$?"
fi

# Function to generate and display system info
get_system_identification() {
    {
        local exit_status=0
        echo -e "\n\e[36mSystem Identification:\e[0m"
        echo

        # System Info
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Hostname:" "$(hostname)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Operating System:" "$(lsb_release -d | cut -f2)"
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "Kernel Version:" "$(uname -r)"

        # CPU Info
        cpu_info=$(lscpu | grep 'Model name' | sed 's/Model name:[[:space:]]*//')
        cpu_cores=$(lscpu | grep '^CPU(s):' | awk '{print $2}')
        printf "\e[36m%-18s\e[0m \e[32m%s (%s cores)\e[0m\n" "CPU Info:" "$cpu_info" "$cpu_cores"

        # GPU Info
        gpu_info=$(lspci | grep -i vga | sed 's/.*: //')
        printf "\e[36m%-18s\e[0m \e[32m%s\e[0m\n" "GPU Info:" "$gpu_info"

        # Memory Info
        total_mem=$(free -h | awk '/^Mem:/ {print $2}')
        used_mem=$(free -h | awk '/^Mem:/ {print $3}')
        printf "\e[36m%-18s\e[0m \e[32m%s / %s\e[0m\n" "Memory Info:" "$used_mem" "$total_mem"

        # Disk Info
        echo -e "\e[36mDisk Info:\e[0m"
        echo -e "\e[36mDrives:\e[0m"
        printf "\e[36m%-10s %-30s %-10s %-15s\e[0m\n" "Device" "Model" "Size" "Used"

        lsblk -d -o NAME,MODEL,SIZE | grep -v 'loop' | while read -r name model size; do
            used=$(df -h | grep "^/dev/${name}" | awk '{print $3}')
            if [[ -z "$used" ]]; then
                used="N/A"
            else
                # Check for different output formats
                if [[ "$used" =~ ^[0-9]+G$ ]]; then
                    # Handle GB format
                    used=${used//G/}
                elif [[ "$used" =~ ^[0-9]+M$ ]]; then
                    # Handle MB format
                    used=${used//M/}
                fi
            fi
            printf "\e[32m%-10s %-30s %-10s %-15s\e[0m\n" "$name" "${model:0:30}" "$size" "$used"
        done

        # Network Info
        echo -e "\n\e[36mNetwork Info:\e[0m"
        ip -br addr show | grep -v '^lo' | while read -r iface ip; do
            printf "  \e[36m%-12s\e[0m \e[32m%s\e[0m\n" "$iface" "$ip"
        done

        echo
    }
    local exit_status=0
    exit_status=$? # Capture the exit status immediately
    if [ $exit_status -ne 0 ]; then
        handle_error "get_system_identification" "$exit_status"
    fi
}

# Run system identification
get_system_identification
get_log_info2

# Check Unbound DNSSEC status with trimmed output and error handling
dnssec_query() {
    local result
    # Use dig with the necessary flags to reduce output and avoid hanging
    result=$(dig dnssec.works @pi.hole +dnssec +nocmd +noall +answer) || handle_error "dnssec_query" "Failed to query DNSSEC status." "dnssec_query"

    if [[ -z "$result" ]]; then
        handle_error "dnssec_query" "No valid DNSSEC response found." "dnssec_query"
    fi

    # Check if the result contains DNSSEC validation
    if echo "$result" | grep -q "RRSIG"; then
        echo "DNSSEC validation passed"
    else
        handle_error "dnssec_query" "DNSSEC validation failed." "dnssec_query"
    fi
}

# Call the function and store the result
dnssec_result=$(dnssec_query)

# Print the result if no error occurred
echo "DNSSEC result for dnssec.works: $dnssec_result"

# Function to backup the script only if it's changed
backup_script() {
    {
        log_message yellow "Backing up script..."

        # Check write permissions for BACKUP_DIR2
        if [[ ! -w "$BACKUP_DIR2" ]]; then
            log_message red "Error: No write permissions for $BACKUP_DIR2. Backup aborted."
            exit 1
        fi

        # Get the latest backup file if it exists
        latest_backup=$(find "$BACKUP_DIR" -name "$(basename "$0")_*.sh" -type f -print0 2>/dev/null | xargs -0 -P 0 sh -c 'ls -t "$@"')
        latest_backup=$(awk 'NR == 1 { print; exit }' <<<"$latest_backup")

        # Compare the current script with the latest backup
        if [ -f "$latest_backup" ] && cmp -s "$0" "$latest_backup"; then
            log_message green "No changes detected. Backup not needed."
        else
            backup_name="$(basename "$0")_$(date +%Y%m%d%H%M%S).sh"

            # Copy to first backup location
            if cp "$0" "$BACKUP_DIR/$backup_name"; then
                log_message green "Script backed up successfully to $BACKUP_DIR."
            else
                log_message red "Failed to backup script to $BACKUP_DIR. Error: $?"
                exit 1
            fi

            # Copy to second backup location
            if cp "$0" "$BACKUP_DIR2/$backup_name"; then
                log_message green "Script backed up successfully to $BACKUP_DIR2."
            else
                log_message red "Failed to backup script to $BACKUP_DIR2. Error: $?"
                # Continue even if second backup fails
            fi
        fi
    } || handle_error "backup_script" "$?"
}

# Backup the script
backup_script

# Function to check sudo permissions
check_sudo_permissions() {
    {
        if ! sudo -A true 2>/dev/null; then
            log_message red "Error: Sudo permissions required but not available"
            log_message yellow "Please ensure SUDO_ASKPASS is properly configured"
            exit 1
        fi
    } || handle_error "check_sudo_permissions" "$?"
}

# shellcheck disable=SC2317
# Function to perform local update
perform_local_update() {
    check_sudo_permissions

    echo
    log_message blue "$(printf '\e[3mUpdating package list...\e[0m')"
    echo
    sudo -A apt-get update 2>&1 | tee -a "$LOG_FILE"
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message red "Error: Failed to update package list"
        handle_error "perform_local_update" "$exit_code"
        return 1
    fi
    log_message green "Package list updated successfully."

    echo
    log_message blue "$(printf '\e[3mUpgrading packages...\e[0m')"
    echo
    sudo -A apt-get upgrade -y 2>&1 | tee -a "$LOG_FILE"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message red "Error: Failed to upgrade packages"
        handle_error "perform_local_update" "$exit_code"
        return 1
    fi
    log_message green "Packages upgraded successfully."

    echo
    log_message blue "$(printf '\e[3mPerforming distribution upgrade...\e[0m')"
    echo
    sudo -A apt-get dist-upgrade -y 2>&1 | tee -a "$LOG_FILE"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message red "Error: Failed to perform distribution upgrade"
        handle_error "perform_local_update" "$exit_code"
        return 1
    fi
    log_message green "Distribution upgrade performed successfully."

    echo
    log_message blue "$(printf '\e[3mRemoving unnecessary packages...\e[0m')"
    echo
    sudo -A apt-get autoremove -y 2>&1 | tee -a "$LOG_FILE"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message red "Error: Failed to remove unnecessary packages"
        handle_error "perform_local_update" "$exit_code"
        return 1
    fi
    log_message green "Unnecessary packages removed successfully."

    echo
    log_message blue "$(printf '\e[3mCleaning up...\e[0m')"
    echo
    sudo -A apt-get clean 2>&1 | tee -a "$LOG_FILE"
    exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_message red "Error: Failed to clean up"
        handle_error "perform_local_update" "$exit_code"
        return 1
    fi
    log_message green "Cleanup completed successfully."

    return 0
}

# Main execution
check_sudo_permissions

if ! perform_local_update; then
    log_message red "Local update process failed"
    exit 1
fi

log_message cyan "Local script completed."

# shellcheck disable=SC2317
# shellcheck disable=SC2029
# Function to execute remote script and retrieve log
execute_remote_script() {
    local remote_user="$1"
    local pihole="${2:-check}"
    local remote_script_remote="$3"
    local remote_log="$4"
    local backup_log="$5"
    local script_name="$6"

    echo
    log_message blue "$(printf '\e[3mExecuting %s update script...\e[0m' "$script_name")"
    echo

    if check_dry_run_mode; then
        echo "ssh $remote_user@$pihole 'bash $remote_script_remote'"
    else
        if ! ssh "$remote_user@$pihole" "bash \"$remote_script_remote\""; then
            handle_error "execute_remote_script" "Failed to execute $script_name script. Check permissions and script content."
            return 1
        fi
    fi

    echo
    log_message blue "$(printf '\e[3mRetrieving %s remote log file...\e[0m' "$script_name")"
    echo

    if check_dry_run_mode; then
        echo "scp $remote_user@$pihole:$remote_log $backup_log"
    else
        if scp "$remote_user@$pihole:$remote_log" "$backup_log"; then
            log_message cyan "Remote log backed up at $backup_log"
        else
            handle_error "execute_remote_script" "Failed to retrieve log file from $script_name"
            return 1
        fi
    fi

    return 0
}

# Run the remote scripts and retrieve logs
execute_remote_script "$REMOTE_USER" "$pihole" "$pihole_Remote" "$REMOTE_LOG" "$pihole_log" "Pi-hole HP Laptop"

execute_remote_script "$REMOTE_USER" "$pihole2" "$pihole2_Remote" "$REMOTE_LOG" "$pihole2_log" "Pi-hole2 HP Envy"

execute_remote_script "$REMOTE_USER" "$AG_backup" "$AG_Backup_Remote" "$REMOTE_LOG" "$AG_Backup_log" "AGeorge-Backup HP Envy"

backup_local_logs() {
    local log_file="$1"
    local backup_dir="${2:-check}"
    local backup_log_file="$3"
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)

    log_message magenta "Starting backup of local logs"

    # Check if log file exists
    if [[ ! -f "$log_file" ]]; then
        handle_error "backup_local_logs" "Log file '$log_file' not found" ""
        return 1
    fi

    # Check if backup directory exists, create it if it doesn't
    if [[ ! -d "$backup_dir" ]]; then
        log_message yellow "Backup directory '$backup_dir' does not exist. Creating it."
        mkdir -p "$backup_dir"
    fi

    # Perform the backup
    cp "$log_file" "$backup_dir/$(basename "$log_file")_$timestamp.log" || handle_error "backup_local_logs" "Failed to copy log file to backup directory" ""
    cp "$log_file" "$backup_log_file" || handle_error "backup_local_logs" "Failed to copy log file to backup log file" ""

    log_message green "Backup of local logs completed successfully"
}

backup_local_logs "$LOG_FILE" "$BACKUP_DIR" "$BACKUP_LOG_FILE"

# Check for errors
check_run_log

log_message cyan "     {{[[[**Completed, Local Script finished.**]]]}}"

# Variables
SCRIPT_NAME="/home/ageorge/Desktop/Update-Script/local_update.sh"
CHANGELOG_FILE="/home/ageorge/Documents/Backups/changelog.txt"

# Check if changelog file and main script exist
if [[ ! -f "$CHANGELOG_FILE" ]]; then
    handle_error "update_changelog" "Changelog file does not exist: $CHANGELOG_FILE"
    return 1
fi

if [[ ! -f "$SCRIPT_NAME" ]]; then
    handle_error "update_changelog" "Main script does not exist: $SCRIPT_NAME"
    return 1
fi

# Function to update changelog
update_changelog() {
    local changelog_file="$1"
    local main_script="${2:-default_script}"
    local current_version="$3"
    # Check if changelog file, main script, and version are provided
    if [[ -z "$changelog_file" || -z "$main_script" || -z "$current_version" ]]; then
        handle_error "update_changelog" "Changelog file, main script, or version is missing"
        return 1
    fi
    if [[ ! -f "$changelog_file" ]]; then
        handle_error "update_changelog" "Changelog file does not exist"
        return 1
    fi
    echo
    log_message blue "Checking for new version..."
    echo
    LAST_LOGGED_VERSION=$(grep -oP '(?<=Script version )\S+' "$changelog_file" | tail -1)
    # Check for changes in the main script
    if ! git diff --quiet "$main_script"; then
        echo
        log_message yellow "===== Changes detected in the main script ====="
        echo
        log_message cyan "Current version: $current_version"
        echo
        log_message green "Enter new version (or press Enter to keep current version):"
        read -rp "$(tput setaf 2)> $(tput sgr0)" NEW_VERSION
        # If no new version is entered, keep the current version
        NEW_VERSION=${NEW_VERSION:-$current_version}
        echo
        log_message green "Enter changelog details:"
        read -rp "$(tput setaf 2)> $(tput sgr0)" CHANGE_DETAILS
        # Update the VERSION variable in the main script
        if [[ "$NEW_VERSION" != "$current_version" ]]; then
            if ! sed -i "s/VERSION=\"$current_version\"/VERSION=\"$NEW_VERSION\"/" "$main_script"; then
                handle_error "update_changelog" "Failed to update version in main script"
                return 1
            fi
            log_message blue "Updated script version to $NEW_VERSION"
        fi
        echo
        log_message blue "Updating changelog..."
        echo
        if ! echo "[$(date +"%Y-%m-%d %H:%M:%S")] Script version $NEW_VERSION" >>"$changelog_file"; then
            handle_error "update_changelog" "Failed to update changelog"
            return 1
        fi
        if ! echo "- $CHANGE_DETAILS" >>"$changelog_file"; then
            handle_error "update_changelog" "Failed to update changelog"
            return 1
        fi
        log_message green "Changelog updated successfully!"
    elif [[ "$current_version" != "$LAST_LOGGED_VERSION" ]]; then
        echo
        log_message blue "Updating changelog for version $current_version..."
        echo
        # Append the new version and a default log message
        if ! echo "[$(date +"%Y-%m-%d %H:%M:%S")] Script version $current_version" >>"$changelog_file"; then
            handle_error "update_changelog" "Failed to update changelog"
            return 1
        fi
        if ! echo "- Log Scanning updated." >>"$changelog_file"; then
            handle_error "update_changelog" "Failed to update changelog"
            return 1
        fi
        log_message green "Changelog updated successfully!"
    else
        echo
        log_message blue "Version $current_version is already logged. No changes made to changelog."
        echo
    fi
}
# Call the function with the existing VERSION variable
update_changelog "$CHANGELOG_FILE" "$SCRIPT_NAME" "$VERSION"

# shellcheck disable=SC1090
# Function to source files from a specific directory
source_from_dir() {
    local file="${2:-default_file}"
    local dir="$1"
    local file="${2:-check}"
    if [[ -d "$dir" && -f "$dir/$file" ]]; then
        source "$dir/$file"
        # Add a directive to specify the location of the sourced file
        . "$dir/$file"
    else
        echo "Error: File $file not found in directory $dir" >&2
        exit 1
    fi
}

# Source your log_functions.sh file using the function
source_from_dir "/home/ageorge/Desktop/Update-Script" "log_functions.sh"

# Example usage (assuming log_functions.sh defines functions for logging)
log_message "This script is located in $(dirname "$0")"

# Validation and setup section
setup_and_validate() {
    # Create cache directory if it doesn't exist
    if [ ! -d "$CACHE_DIR" ]; then
        if ! mkdir -p "$CACHE_DIR"; then
            handle_error "setup_and_validate" "Failed to create cache directory $CACHE_DIR"
            return 1
        fi
    fi

    # Set proper permissions for cache directory
    if ! chmod 700 "$CACHE_DIR"; then
        handle_error "setup_and_validate" "Failed to set permissions for cache directory $CACHE_DIR"
        return 1
    fi

    # Create last run file if it doesn't exist
    if [ ! -f "$LAST_RUN_FILE" ]; then
        if ! touch "$LAST_RUN_FILE"; then
            handle_error "setup_and_validate" "Failed to create last run file $LAST_RUN_FILE"
            return 1
        fi
    fi

    # Set proper permissions for last run file
    if ! chmod 600 "$LAST_RUN_FILE"; then
        handle_error "setup_and_validate" "Failed to set permissions for last run file $LAST_RUN_FILE"
        return 1
    fi

    # Validate environment variables
    for var in LOG_FILE LOCAL_UPDATE_ERROR LOCAL_UPDATE_DEBUG BACKUP_LOG_DIR SEEN_ERRORS_FILE temp_error_counts; do
        if [ -z "${!var}" ]; then
            handle_error "setup_and_validate" "Environment variable '$var' is not set."
            return 1
        fi
    done

    # Validate remote access (basic check)
    if ! ssh -o ConnectTimeout=5 "$REMOTE_USER@$pihole" exit &>/dev/null; then
        handle_error "setup_and_validate" "Cannot connect to remote host $pihole as $REMOTE_USER. Please ensure SSH access is configured correctly."
        return 1
    fi

    # Validate 'parallel' installation
    if ! parallel --version &>/dev/null; then
        handle_error "setup_and_validate" "'parallel' command not found. Please install GNU Parallel."
        # Optionally provide installation instructions
        return 1
    fi

    log_message green "Setup and validation completed successfully."
}

# Call the setup and validation function
setup_and_validate

# Export functions and variables for use in subshells
export -f get_last_position
export -f set_last_position
export CACHE_DIR
export SUDO_ASKPASS
export LOCAL_UPDATE_ERROR
export temp_error_counts

# Define local and remote log paths
logs=(
    "$LOG_FILE:Local Update Log:local"
    "/var/log/auth.log:Auth Log:local"
    "/var/log/dpkg.log:DPKG Log:local"
    "/var/log/fail2ban.log:Fail2Ban Log:local"
    "/var/log/gpu-manager.log:GPU Manager Log:local"
    "/var/log/kern.log:Kernel Log:local"
    "/var/log/mintsystem.log:Mint System Log:local"
    "/var/log/syslog:System Log:local"
    "/var/log/pihole/FTL.log:Pi-hole FTL Log:remote1:sudo"
    "/var/log/pihole/pihole.log:Pi-hole Log:remote1:sudo"
    "/var/log/fail2ban.log:Fail2Ban Log:remote1"
    "/var/log/kern.log:Kernel Log:remote1"
    "/var/log/syslog:System Log:remote1"
    "/tmp/remote_update.log:Remote Update:remote1"
    "/var/log/fail2ban.log:Fail2Ban Log:remote2"
    "/var/log/kern.log:Kernel Log:remote2"
    "/var/log/syslog:System Log:remote2"
    "/tmp/remote_update.log:Remote Update:remote2"
    "/var/log/fail2ban.log:Fail2Ban Log:remote3"
    "/var/log/kern.log:Kernel Log:remote3"
    "/var/log/syslog:System Log:remote3"
    "/tmp/remote_update.log:Remote Update:remote3"
)

# shellcheck disable=SC2034
# shellcheck disable=SC2029
# Function to get log information
get_log_info() {
    echo -e "\n\e[36mLog Information:\e[0m"
    local local_logs=()
    local remote_logs1=()
    local remote_logs2=()
    local remote_logs3=()

    for log in "${logs[@]}"; do
        IFS=':' read -r path name location sudo_flag <<<"$log"
        case "$location" in
        "local")
            if [ -f "$path" ]; then
                log_size=$(du -h "$path" | cut -f1)
                local_logs+=("✓ $name:$log_size")
            else
                local_logs+=("✗ $name:Not Found")
            fi
            ;;
        "remote1")

            remote_log=$(ssh "$REMOTE_USER@$pihole" "test -f '$path' && ${sudo_flag:+sudo }du -h '$path' || echo 'Not Found'")
            process_remote_log remote_logs1 "$name" "$remote_log"
            ;;
        "remote2")

            remote_log=$(ssh "$REMOTE_USER@$pihole2" "test -f '$path' && ${sudo_flag:+sudo }du -h '$path' || echo 'Not Found'")
            process_remote_log remote_logs2 "$name" "$remote_log"
            ;;
        "remote3")

            remote_log=$(ssh "$REMOTE_USER@$AG_backup" "test -f '$path' && ${sudo_flag:+sudo }du -h '$path' || echo 'Not Found'")
            process_remote_log remote_logs3 "$name" "$remote_log"
            ;;
        esac
    done

    print_log_table "Local Logs" local_logs "Remote Logs (Pi-hole)" remote_logs1
    print_log_table "Remote Logs (Pi-hole2)" remote_logs2 "Remote Logs (AGeorge-Backup)" remote_logs3
}

process_remote_log() {
    local -n logs_array=$1
    local name=$2
    local remote_log=$3

    if [[ $remote_log == *"Not Found"* ]]; then
        logs_array+=("✗ $name:Not Found")
    else
        log_size=$(echo "$remote_log" | cut -f1)
        logs_array+=("✓ $name:$log_size")
    fi
}

print_log_table() {
    local title1=$1
    local -n logs1=$2
    local title2=$3
    local -n logs2=$4
    local name1
    local size1
    local name2
    local size2

    printf "\e[36m%-36s %-10s  \e[36m%-36s %-10s\e[0m\n" "$title1:" "Size:" "$title2:" "Size:"
    local max_lines=$((${#logs1[@]} > ${#logs2[@]} ? ${#logs1[@]} : ${#logs2[@]}))
    for ((i = 0; i < max_lines; i++)); do
        local log1=${logs1[i]:-""}
        local log2=${logs2[i]:-""}
        name1=$(echo "$log1" | cut -d':' -f1)
        size1=$(echo "$log1" | cut -d':' -f2)
        name2=$(echo "$log2" | cut -d':' -f1)
        size2=$(echo "$log2" | cut -d':' -f2)
        printf "   \e[32m%-36s\e[0m : \e[32m%-10s\e[0m  \e[32m%-36s\e[0m : \e[32m%-10s\e[0m\n" "$name1" "$size1" "$name2" "$size2"
    done
    echo -e "\n"
}

# Function to scan and classify logs
scan_and_classify_logs() {
    log_files=("${logs[@]}")
    true >"$temp_error_counts" #Clear the temporary file
    position_file="$CACHE_DIR/"
    basename_result=$(basename "$log_file")
    position_file+="$basename_result.pos"
    # Add a timestamp for this run
    echo -e "\n--- Scan started at $(date) ---" >>"$centralized_error_log"

    echo -e "\n\e[36mScanning Logs:\e[0m"

    # Define a function to process each log file
    process_log() {
        local log_file="$1"
        local log_name="${2:-check}"
        local log_type="$3"
        local sudo_required="${4:-}"
        local last_position=0

        case "$log_type" in
        "local")
            if [ -f "$log_file" ] && [ -r "$log_file" ]; then
                echo -e "\e[36mScanning Local Log: $log_name\e[0m"
                last_position=$(get_last_position "$log_file")
                if ! [[ "$last_position" =~ ^[0-9]+$ ]]; then
                    last_position=0
                fi
                tail -n +$((last_position + 1)) "$log_file" 2>/dev/null | process_log_content "$log_name"
                new_last_position=$(wc -l <"$log_file")
                set_last_position "$log_file" "$new_last_position"
            else
                echo -e "\e[31m[ERROR]\e[0m Cannot read log file: $log_name"
                echo "PermissionError" >>"$temp_error_counts"
                echo "[$(date)] Cannot read log file: $log_name" >>"$centralized_error_log"
            fi
            ;;
        "remote1")
            remote_log_scan "$REMOTE_USER" "$pihole" "$log_file" "$log_name" "$sudo_required"
            ;;
        "remote2")
            remote_log_scan "$REMOTE_USER" "$pihole2" "$log_file" "$log_name" "$sudo_required"
            ;;
        "remote3")
            remote_log_scan "$REMOTE_USER" "$AG_backup" "$log_file" "$log_name" "$sudo_required"
            ;;
        esac
    }

    remote_log_scan() {
        local remote_user="$1"
        local pihole="${2:-check}"
        local log_file="$3"
        local log_name="$4"
        local sudo_required="$5"

        echo -e "\e[36mScanning Remote Log: $log_name on $pihole\e[0m"
        local ssh_command="export SUDO_ASKPASS='$SUDO_ASKPASS'; ${sudo_required:+sudo -A} cat '$log_file'"
        if ssh -o BatchMode=no -o ConnectTimeout=5 "$remote_user@$pihole" "$ssh_command" 2>/dev/null | process_log_content "$log_name"; then
            :
        else
            echo -e "\e[31m[ERROR]\e[0m Cannot read remote log file: $log_name on $pihole"
            echo "PermissionError" >>"$temp_error_counts"
            echo "[$(date)] Cannot read remote log file: $log_name on $pihole" >>"$centralized_error_log"
        fi
    }

    # Define the maximum number of error lines to display
    MAX_ERRORS=10
    error_count=0
    timestamp=$(date)

    process_log_content() {
        local log_name="$1"
        local errors=""
        while IFS= read -r line; do
            if [[ "$line" =~ [Ee]rror|[Ee]xception|[Ff]ailed|[Ff]ailure ]]; then
                error_message="[$timestamp] $log_name: $line"
                echo -e "\e[31m[ERROR]\e[0m $error_message"
                errors+="$error_message"$'\n'

                ((error_count++))
                if [[ $error_count -ge $MAX_ERRORS ]]; then
                    break
                fi
            fi
        done

        # Write all errors at once to avoid multiple disk writes
        echo "$errors" >>"$centralized_error_log"
        echo "$errors" >>"$LOCAL_UPDATE_ERROR"
        echo "$errors" >>"$SEEN_ERRORS_FILE"
    }

    cat "$SEEN_ERRORS_FILE" >>"$LOCAL_UPDATE_ERROR"
    cat "$centralized_error_log" >>"$LOCAL_UPDATE_ERROR"

    # Export the functions and variables for parallel execution
    export -f process_log process_log_content remote_log_scan
    export centralized_error_log SEEN_ERRORS_FILE REMOTE_USER pihole pihole2 AG_backup SUDO_ASKPASS
    export MAX_ERRORS

    # Run the log processing in parallel with 6 cores
    printf "%s\n" "${log_files[@]}" | parallel -j 6 --colsep ':' process_log '{1}' '{2}' '{3}' '{4}'

    # Count errors
    declare -A error_counts
    total_errors=0
    while IFS= read -r error_type; do
        if [[ -n "$error_type" ]]; then # Check if error_type is not empty
            ((error_counts[$error_type]++))
            ((total_errors++))
        fi
    done <"$temp_error_counts"

    # Print last 10 unique errors
    echo -e "\n\nSummary of last 10 new logged errors:"
    sort "$centralized_error_log" | uniq -c | sort -rn | head -n 10

    # Dump errors to LOCAL_UPDATE_ERROR
    echo -e "\n\e[36mDumping errors to $LOCAL_UPDATE_ERROR\e[0m"
    cat "$temp_error_counts" >>"$LOCAL_UPDATE_ERROR"

    # Add a timestamp for the end of this run
    echo -e "--- Scan completed at $(date) ---\n" >>"$centralized_error_log"
}

# Call the get_log_info function
get_log_info

# Call the scan_and_classify_logs function
scan_and_classify_logs

echo -e "\nFinished scanning logs."

# Update last run timestamp
date +%s >"$LAST_RUN_FILE"

# Cleanup old entries from seen errors file (optional)
if [ -f "$SEEN_ERRORS_FILE" ]; then
    tail -n 10000 "$SEEN_ERRORS_FILE" >"${SEEN_ERRORS_FILE}.tmp" && mv "${SEEN_ERRORS_FILE}.tmp" "$SEEN_ERRORS_FILE"
fi

# Define the box characters with color codes
u_left="\e[36m╭\e[0m"
u_right="\e[36m╮\e[0m"
b_left="\e[36m╰\e[0m"
b_right="\e[36m╯\e[0m"
v_bar="\e[36m│\e[0m"
h_bar="\e[36m─\e[0m"

# Function to scan the network for active hosts, hostnames, and MAC addresses
scan_network_for_active_hosts() {
    local nmap_output
    nmap_output=$(nmap -sn 192.168.1.0/24 | grep "Nmap scan report" | cut -f5,6 -d' ')

    # Create an array to store the results
    local -a hosts
    while IFS= read -r line; do
        hosts+=("$line")
    done <<<"$nmap_output"

    # Loop through the array to get the hostnames and MAC addresses
    for entry in "${hosts[@]}"; do
        ip=$(echo "$entry" | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
        hostname=${entry%% *}
        mac_address=$(arp -an "$ip" | awk '{print $4}' | tr -d '[:space:]')

        # Print the result
        echo "$hostname $ip $mac_address"
    done
}

# Function to scan for open services on common ports
scan_open_services() {
    local ip="$1"
    open_ports=$(nmap -p 22,80,443,53,67,68,25,110,143 "$ip" | grep "^22/tcp\|^80/tcp\|^443/tcp\|^53/tcp\|^67/tcp\|^68/tcp\|^25/tcp\|^110/tcp\|^143/tcp" | awk '{print $1}' | tr '\n' ', ' | sed 's/, $//')
    echo "${open_ports:-None}"
}

# Function to calculate the maximum length of entries in each column
calculate_max_widths() {
    local max_ip_width=0
    local max_hostname_width=0
    local max_mac_width=0
    local max_services_width=0

    while read -r hostname ip mac; do
        [ ${#hostname} -gt "$max_hostname_width" ] && max_hostname_width=${#hostname}
        [ ${#ip} -gt "$max_ip_width" ] && max_ip_width=${#ip}
        [ ${#mac} -gt "$max_mac_width" ] && max_mac_width=${#mac}
        services=$(scan_open_services "$ip")
        [ ${#services} -gt "$max_services_width" ] && max_services_width=${#services}
    done < <(scan_network_for_active_hosts)

    echo "$max_hostname_width $max_ip_width $max_mac_width $max_services_width"
}

# Function to print results in a formatted table with color
print_diagram() {
    read -r max_hostname_width max_ip_width max_mac_width max_services_width < <(calculate_max_widths)

    # Adjust the widths for the box drawing
    local total_width=$((max_hostname_width + max_ip_width + max_mac_width + max_services_width + 4 * 3 + 4))

    # Print the header
    printf "%b\n" "${u_left}$(printf "%${total_width}s" "" | tr " " "${h_bar}")${u_right}"
    printf "%b\n" "${v_bar} \e[96m$(printf "%-${max_hostname_width}s" "Hostname")\e[0m ${v_bar} \e[96m$(printf "%-${max_ip_width}s" "IP Address")\e[0m ${v_bar} \e[96m$(printf "%-${max_mac_width}s" "MAC Address")\e[0m ${v_bar} \e[96m$(printf "%-${max_services_width}s" "Open Services")\e[0m ${v_bar}"
    printf "%b\n" "${u_left}$(printf "%${total_width}s" "" | tr " " "${h_bar}")${u_right}"

    # Loop through each active host and display the information
    while read -r hostname ip mac; do
        services=$(scan_open_services "$ip")

        # Print the row
        printf "%b\n" "${v_bar} \e[92m$(printf "%-${max_hostname_width}s" "${hostname:-Unknown}")\e[0m ${v_bar} \e[92m$(printf "%-${max_ip_width}s" "$ip")\e[0m ${v_bar} \e[92m$(printf "%-${max_mac_width}s" "${mac:-Unknown}")\e[0m ${v_bar} \e[92m$(printf "%-${max_services_width}s" "${services}")\e[0m ${v_bar}"
    done < <(scan_network_for_active_hosts)

    # Print the footer
    printf "%b\n" "${b_left}$(printf "%${total_width}s" "" | tr " " "${h_bar}")${b_right}"
}

print_diagram
