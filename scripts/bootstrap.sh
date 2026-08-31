#!/usr/bin/env bash

set -euo pipefail

# Const Variables
# VM User
DEV_USER="dev"
DEV_UID="1000"
DEV_GID="1000"

# VM Workspace
WORKSPACE="/workspace"

log_file="/var/log/bootstrap_$(date '+%Y%m%d_%H%M%S').log"

# Functions
# Log output
# Usage: log <level> <message>
# Example: log "INFO" "Process Start"
log(){
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%dT%H:%M:%S.%3NZ' --utc)

    echo "$timestamp [$level] [$$] $message" | tee -a "$log_file"
}

# Error output
# Usage: error <message>
# Example: error "Process Error"
error(){
    local message="$1"
    local timestamp=$(date '+%Y-%m-%dT%H:%M:%S.%3NZ' --utc)

    echo "$timestamp [ERROR] [$$] $message" | tee -a "$log_file" >&2
}

# Start bootstrap
log "INFO" "===Bootstrap start==="

# Package update
log "INFO" "===Phase1: Update packages==="
pacman -Syu --noconfirm

# Dev package install
log "INFO" "===Phase2: Install development packages==="
pacman -S --needed --noconfirm base-devel git openai-codex

# Create dev user and group
log "INFO" "===Phase3: Setup dev user==="
if ! getent group "$DEV_GID" > /dev/null; then
    groupadd --gid "$DEV_GID" "$DEV_USER"
fi
if ! id "$DEV_USER" > /dev/null 2>&1; then
    useradd --create-home --uid "$DEV_UID" --gid "$DEV_GID" --shell /bin/bash "$DEV_USER"
fi

# Create workspace
log "INFO" "===Phase4: Create workspace==="
mkdir -p "$WORKSPACE"
chown "$DEV_UID:$DEV_GID" "$WORKSPACE"

# Config PATH
log "INFO" "===Phase5: Configuring PATH==="
BASH_PROFILE="/home/$DEV_USER/.bash_profile"
touch "$BASH_PROFILE"

if ! grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$BASH_PROFILE"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$BASH_PROFILE"
fi

chown "$DEV_UID:$DEV_GID" "$BASH_PROFILE"


# End bootstrap
log "INFO" "===Bootstrap completed==="
