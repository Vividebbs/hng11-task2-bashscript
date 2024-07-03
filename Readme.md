# User and Group Management Script

## Overview

This bash script automates the process of creating users and groups, setting up home directories with appropriate permissions and ownership, generating random passwords for the users, logging all actions to `/var/log/user_management.log`, and securely storing the generated passwords in `/var/secure/user_passwords.csv`. It also supports a dry-run mode for testing purposes.

## Usage

To run the script, use the following command:
```bash
sudo bash create_users.sh <name-of-text-file> [--dry-run]
```

### Arguments

- `<name-of-text-file>`: The path to the text file containing the list of usernames and groups.
- `[--dry-run]`: Optional flag to simulate the actions without making any changes.

### Input File Format

The input file should have the following format:
```
username; groups
```
- `username`: The name of the user to be created.
- `groups`: Comma-separated list of groups the user should be added to (excluding the personal group).

### Example

```plaintext
adeola; sudo,dev,www-data,staff
bisi; sudo,hr,finance
chiamaka; dev,www-data,qa
```

## Features

- **User and Group Creation**: Creates users with a personal group and adds them to specified groups.
- **Home Directory Setup**: Ensures home directories are created with appropriate permissions.
- **Password Generation**: Generates a random 12-character password for each user.
- **Logging**: Logs all actions to `/var/log/user_management.log`.
- **Secure Password Storage**: Stores passwords in `/var/secure/user_passwords.csv` with restricted permissions.
- **Dry-Run Mode**: Supports simulating actions without making changes.

## Logs and Passwords

- **Logs**: Actions are logged to `/var/log/user_management.log`.
- **Passwords**: Generated passwords are stored securely in `/var/secure/user_passwords.csv`.

## Technical Article

### Automating User and Group Management with a Bash Script

Managing users and groups on a Linux system can be a repetitive and error-prone task. To streamline this process, we’ve developed a bash script that automates user creation, group assignment, home directory setup, password generation, and action logging. This article explains the script step-by-step and links to the HNG Internship program for those looking to enhance their development skills.

### Why Automate User Management?

Automation reduces the risk of human error, saves time, and ensures consistency in repetitive tasks. By automating user and group management, system administrators can focus on more critical tasks while maintaining a secure and well-organized system.

### Script Breakdown

#### Setting Locale and Checking Root Privileges

The script begins by setting the locale to avoid illegal byte sequence errors and ensuring it is run with root privileges.

```bash
export LC_ALL=C

if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mThis script must be run as root\e[0m"
    exit 1
fi
```

#### Input File and Dry-Run Mode

The script requires an input file containing usernames and groups. It also supports a `--dry-run` flag to simulate actions without making changes.

```bash
if [ -z "$1" ]; then
    echo -e "\e[33mUsage: $0 <name-of-text-file> [--dry-run]\e[0m"
    exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.csv"
DRY_RUN=false

if [[ "$2" == "--dry-run" ]]; then
    DRY_RUN=true
    echo -e "\e[34mRunning in dry-run mode. No changes will be made.\e[0m"
fi
```

#### Creating Directories and Files

If not in dry-run mode, the script creates the necessary directories and files for logging and storing passwords securely.

```bash
if [ "$DRY_RUN" = false ]; then
    mkdir -p /var/secure
    touch $LOG_FILE
    touch $PASSWORD_FILE
    chmod 600 $PASSWORD_FILE
fi
```

#### Logging and Password Generation Functions

The `log_action` function logs actions to a file, and the `generate_password` function creates a random 12-character password.

```bash
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}
```

#### Processing the Input File

The script reads the input file line by line, trims whitespace, and processes each user and their groups.

```bash
while IFS=';' read -r username groups; do
    username=$(echo $username | xargs)
    groups=$(echo $groups | xargs)
```

#### Checking for Existing Users

If a user already exists, the script logs the action and skips to the next user.

```bash
    if id "$username" &>/dev/null; then
        echo -e "\e[33mUser $username already exists. Skipping...\e[0m"
        log_action "User $username already exists."
        continue
    fi
```

#### Creating Users and Personal Groups

The script creates the user and their personal group, logging the action.

```bash
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
```

#### Adding Users to Additional Groups

The script processes additional groups, creating them if they don’t exist, and adds the user to each group.

```bash
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
        group=$(echo $group | xargs)
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
```

#### Setting User Passwords

The script generates a password and sets it for the user, logging the action.

```bash
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
```

#### Storing Passwords Securely

The script stores the generated passwords in a secure file with restricted permissions.

```bash
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
```

## Learn More

To learn more about enhancing your development skills and becoming a world-class DevOps Engineer, check out the following links from the HNG Internship program:

- [HNG Internship](https://hng.tech/internship)
- [Hire HNG Interns](https://hng.tech/hire)
- [HNG Premium](https://hng.tech/premium)

This script and article are part of the HNG Internship program, aimed at providing hands-on experience and skill development for aspiring techies.