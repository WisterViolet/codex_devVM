#!/usr/bin/env bash
set -euo pipefail

# Variables
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SQUID_CONFIG="$REPO_DIR/squid/squid.conf"
RUNTIME_DOMAINS="$REPO_DIR/squid/domains-runtime.txt"


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

if [[ ! -f "$SQUID_CONFIG" ]]; then
    error "$SQUID_CONFIG not found."
    exit 1;
fi

if [[ ! -f "$RUNTIME_DOMAINS" ]]; then
    error "$RUNTIME_DOMAINS not found."
    exit 1;
fi

log "INFO" "===Phase1: Installing Squid configuration==="

if [[ -f /etc/squid/squid.conf && ! -f /etc/squid/squid.conf_bck ]]; then
    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf_bck
fi

sudo install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$SQUID_CONFIG" \
    /etc/squid/squid.conf

sudo install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$RUNTIME_DOMAINS" \
    /etc/squid/codex-allowed-domains.txt

log "INFO" "===Phase2: Validating Squid configuration==="

sudo squid -k parse

log "INFO" "===Phase3: Starting Squid==="

sudo systemctl enable --now squid.service

log "INFO" "===Proxy setup completed==="
