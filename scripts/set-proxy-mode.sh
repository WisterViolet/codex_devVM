#!/usr/bin/env bash
set -euo pipefail

# Variables
MODE="${1:-}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

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


case "$MODE" in
    runtime)
        DOMAIN_FILE="$REPO_DIR/squid/domains-runtime.txt"
        ;;

    provisioning)
        DOMAIN_FILE="$REPO_DIR/squid/domains-provisioning.txt"
        ;;

    *)
        error "Usage: $0 {runtime|provisioning}"
        ;;
esac

if [[ ! -f "$DOMAIN_FILE" ]]; then
    error "Error: $DOMAIN_FILE not found."
    exit 1;
fi

log "INFO" "===Phase1: Switching Squid policy to $MODE==="

sudo install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$DOMAIN_FILE" \
    /etc/squid/codex-allowed-domains.txt


sudo squid -k check
sudo squid -k parse
sudo squid -k reconfigure

log "INFO" "===Proxy mode: $MODE==="
