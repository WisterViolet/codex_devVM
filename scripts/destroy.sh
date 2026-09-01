#!/usr/bin/env bash
set -euo pipefail

# Variables
VM_NAME="codex-dev-vm"

LOCAL_CODEX="/home/dev/.codex"
PERSIST="/mnt/codex-persist"

mkdir -p "$HOME/.local/share/log"
log_file="$HOME/.local/share/log/destroy_vm_$(date '+%Y%m%d_%H%M%S').log"

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


# Check VM prerequiies
log "INFO" "===Phase0: Check instance==="

if ! incus info "$VM_NAME" > /dev/null 2>&1; then
    error "Instance '$VM_NAME' does not exist."
    exit 1
fi

STATE="$(incus list $VM_NAME --format csv --columns s)"

# If VM Running, sync codex credentials and configs
if [[ "$STATE" == "RUNNING" ]]; then
    log "INFO" "===Syncing Codex credentials==="

    if incus exec "$VM_NAME" -- test -d "$PERSIST"; then
        incus exec "$VM_NAME" -- su - dev -c '
            set -eu

            LOCAL="$HOME/.codex"
            PERSIST="/mnt/codex-persist"

            for file in auth.json config.toml; do
                [ -f "$LOCAL/$file" ] || continue

                tmp="$(mktemp  $PERSIST/.$file.$$.XXXXXX)"

                cp "$LOCAL/$file" "$tmp"
                chmod 600 "$tmp"
                mv -f "$tmp" "$PERSIST/$file"
            done
        '
    else
        error "Persistent Codex volume not mounted."
        exit 1
    fi

    log "INFO" "Stopping VM"
    incus stop "$VM_NAME"
fi

log "INFO" "===Phase1: Delete VM==="
incus delete "$VM_NAME"

log "INFO" "===VM $VM_NAME deleted. Persist Codex credentials were saved==="
