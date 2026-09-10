#!/usr/bin/env bash
set -euo pipefail

# Variables
NETWORK="codexbr0"
ACL="codex-isolation"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"&&pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.."&&pwd)"

NETWORK_CONFIG="$REPO_DIR/incus/network/codexbr0.yaml"
ACL_CONFIG="$REPO_DIR/incus/network/codex-isolation.yaml"

mkdir -p "$HOME/.local/share/log"
log_file="$HOME/.local/share/log/create_vm_$(date '+%Y%m%d_%H%M%S').log"

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

# Check Config file
log "INFO" "===Phase0: Check configuration files==="

if [[ ! -f "$NETWORK_CONFIG" ]]; then
    echo "Error: network configuration not found: $NETWORK_CONFIG" >&2
    exit 1
fi

if [[ ! -f "$ACL_CONFIG" ]]; then
    echo "Error: ACL configuration not found: $ACL_CONFIG" >&2
    exit 1
fi

# Apply ACL
log "INFO" "===Phase1: Applying ACL: $ACL==="

if incus network acl show "$ACL" >/dev/null 2>&1; then
    incus network acl edit "$ACL" < "$ACL_CONFIG"
else
    incus network acl create "$ACL" < "$ACL_CONFIG"
fi

# Apply Network
log "INFO" "===Phase2: Applying network: $NETWORK==="

if incus network show "$NETWORK" >/dev/null 2>&1; then
    incus network edit "$NETWORK" < "$NETWORK_CONFIG"
else
    incus network create "$NETWORK" --type=bridge < "$NETWORK_CONFIG"
fi

# Apply Network
log "INFO" "===Phase3: Verifying configuration==="

incus network acl show "$ACL"
incus network show "$NETWORK"

log "INFO" "===Network setup completed.==="

