#!/usr/bin/env bash

# WARNING

# This is a backup of a script living in a different directory
# If run as-is it will not work.
# It needs a set of files in a directory $PARENT_DIR/installers/{argo.sh cloudflared.sh...}
# In Inigo's DSLab environment the script is at /home/jovyan/system_setup/install-packages.sh

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root. Please run it with sudo or as root user."
  exit 1
fi

SCRIPT_DIR=$(dirname "$(realpath "$0")")
INSTALLERS_DIR="$SCRIPT_DIR/installers"

PACKAGES=("direnv" "rclone" "kubectl" "argo" "cloudflared" "k9s")

log_install() {
    local package_name="$1"
    local status="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$status" in
        "start")
            echo "[$timestamp] Starting installation of $package_name..."
            ;;
        "end")
            echo "[$timestamp] Finished installation of $package_name."
            ;;
        "error")
            echo "[$timestamp] ERROR: Failed to install $package_name"
            ;;
        *)
            echo "[$timestamp] $package_name: $status"
            ;;
    esac
}

install_package() {
    local package_name="$1"
    local installer_script="$INSTALLERS_DIR/$package_name.sh"
    
    if [[ ! -f "$installer_script" ]]; then
        log_install "$package_name" "error"
        echo "ERROR: Installer script not found: $installer_script"
        return 1
    fi
    
    if [[ ! -x "$installer_script" ]]; then
        log_install "$package_name" "error"
        echo "ERROR: Installer script is not executable: $installer_script"
        return 1
    fi
    
    log_install "$package_name" "start"
    if "$installer_script"; then
        log_install "$package_name" "end"
        return 0
    else
        log_install "$package_name" "error"
        echo "ERROR: Installation failed for $package_name"
        return 1
    fi
}

for package in "${PACKAGES[@]}"; do
    install_package "$package"
    if [[ $? -ne 0 ]]; then
        echo "Stopping installation due to error with $package"
        exit 1
    fi
done