#!/bin/bash

# Set locale to avoid illegal byte sequence errors
export LC_ALL=C

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root\e[0m"
    exit 1
fi

# Check if input file is provided
if [ -z "$1" ]; then
    echo -e "\e[33mUsage: $0 <name-of-text-file> [--dry-run]\e[0m"
    exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"
DRY_RUN=false

# Check for dry-run flag
if [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "\e[34mRunning in dry-run mode. No changes will be made.\e[0m"
fi

# Create necessary directories and files if not in dry-run mode
if [ "$DRY_RUN" = false ]; then
    mkdir -p /var/secure
    touch $LOG_FILE
    touch $PASSWORD_FILE
    chmod 600 $PASSWORD_FILE
fi

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Read the input file
while IFS=';' read -r username groups; do
    username=$(echo $username | xargs) # trim whitespace
    groups=$(echo $groups | xargs)     # trim whitespace

    if id "$username" &>/dev/null; then
        echo -e "\e[33mUser $username already exists. Skipping...\e[0m"
        log_action "User $username already exists."
        continue
    fi

    # Simulate or create user and their personal group
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[34m(DRY-RUN) Would create user $username with personal group.\e[0m"
    else
        if useradd -m -s /bin/bash -G $username $username; then
            echo -e "\e[32mCreated user $username with personal group.\e[0m"
            log_action "Created user $username with personal group."
        else
            echo -e "\e[31mFailed to create user $username.\e[0m"
            log_action "Failed to create user $username."
            continue
        fi
    fi

    # Add user to additional groups
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        group=$(echo $group | xargs) # trim whitespace
        if ! getent group $group > /dev/null 2>&1; then
            if [ "$DRY_RUN" = true ]; then
                echo -e "\e[34m(DRY-RUN) Would create group $group.\e[0m"
            else
                if groupadd $group; then
                    echo -e "\e[32mCreated group $group.\e[0m"
                    log_action "Created group $group."
                else
                    echo -e "\e[31mFailed to create group $group.\e[0m"
                    log_action "Failed to create group $group."
                    continue
                fi
            fi
        fi
        if [ "$DRY_RUN" = true ]; then
            echo -e "\e[34m(DRY-RUN) Would add user $username to group $group.\e[0m"
        else
            if usermod -aG $group $username; then
                echo -e "\e[32mAdded user $username to group $group.\e[0m"
                log_action "Added user $username to group $group."
            else
                echo -e "\e[31mFailed to add user $username to group $group.\e[0m"
                log_action "Failed to add user $username to group $group."
            fi
        fi
    done

    # Generate password and set it for the user
    password=$(generate_password)
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[34m(DRY-RUN) Would set password for user $username.\e[0m"
    else
        if echo "$username:$password" | chpasswd; then
            echo -e "\e[32mSet password for user $username.\e[0m"
            log_action "Set password for user $username."
        else
            echo -e "\e[31mFailed to set password for user $username.\e[0m"
            log_action "Failed to set password for user $username."
        fi
    fi

    # Store the password in the secure file
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[34m(DRY-RUN) Would store password for user $username.\e[0m"
    else
        if echo "$username,$password" >> $PASSWORD_FILE; then
            echo -e "\e[32mStored password for user $username.\e[0m"
            log_action "Stored password for user $username."
        else
            echo -e "\e[31mFailed to store password for user $username.\e[0m"
            log_action "Failed to store password for user $username."
        fi
    fi

done < "$INPUT_FILE"

if [ "$DRY_RUN" = true ]; then
    echo -e "\e[34m(DRY-RUN) User creation process simulated. No changes were made.\e[0m"
else
    echo -e "\e[34mUser creation process completed. Check $LOG_FILE and $PASSWORD_FILE for details.\e[0m"
fi
