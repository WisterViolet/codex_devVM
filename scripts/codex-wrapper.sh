#!/usr/bin/env bash
set -euo pipefail

# Enviroments
PROXY="http://10.200.200.1:3128"
export HTTP_PROXY="$PROXY"
export HTTPS_PROXY="$PROXY"

export http_proxy="$PROXY"
export https_proxy="$PROXY"

export NO_PROXY="localhost,127.0.0.1"
export no_proxy="$NO_PROXY"

# Const Variables
PERSIST="/mnt/codex-persist"
LOCAL="$HOME/.codex"

mkdir -p "$HOME/.local/share/log"
log_file="$HOME/.local/share/log/codex-wrapper_$(date '+%Y%m%d_%H%M%S').log"

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

# Restore authentification and config from persist volume
restore(){
    for file in auth.json; do
        if [[ ! -f "$LOCAL/$file" && -f "$PERSIST/$file" ]]; then
            cp "$PERSIST/$file" "$LOCAL/$file"
            chmod 600 "$LOCAL/$file"
        fi
    done
}

# Save authentification and config to persist volume
save(){
    for file in auth.json; do
        [[ -f "$LOCAL/$file" ]] || continue

        tmp=$(mktemp "$PERSIST/.$file.$$.XXXXXX")

        cp "$LOCAL/$file" "$tmp"
        chmod 600 "$tmp"
        mv -f "$tmp" "$PERSIST/$file"
    done
    log "INFO" "===Save authentification==="
}

log "INFO" "===Restore authentification==="
mkdir -p "$LOCAL"
chmod 700 "$LOCAL"
restore
trap 'save || true' EXIT

/usr/bin/codex "$@"

