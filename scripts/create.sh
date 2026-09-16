#!/usr/bin/env bash
set -euo pipefail

# Variables
VM_NAME="codex-dev-vm"
IMAGE="images:archlinux/current"



STORAGE_POOL="default"
AUTH_VOLUME="codex-auth"
AUTH_DEVICE="codex-persist"
AUTH_MOUNT="/mnt/codex-persist"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")";pwd)"
REPO_DIR="$(cd -- "$SCRIPT_DIR/..";pwd)"
VM_CONFIG="${REPO_DIR}/incus/codex-dev.yaml"

BOOTSTRAP="${SCRIPT_DIR}/bootstrap.sh"
WRAPPER="${SCRIPT_DIR}/codex-wrapper.sh"
SETUP_PROXY="${SCRIPT_DIR}/setup-proxy.sh"
SET_PROXY_MODE="${SCRIPT_DIR}/set-proxy-mode.sh"
MIRRORLIST="/etc/pacman.d/mirrorlist"

NETWORK="codexbr0"
ACL="codex-isolation"

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


rollback() {
    if [[ "$PROXY_PROVISIONING" == true ]]; then
        log "INFO" "===Restoring proxy to runtime mode==="

        if ! "$SET_PROXY_MODE" runtime; then
            error "Failed to restore proxy to runtime mode."
        fi
    fi
    if [[ "$INPROGRESS_VM" == true ]]; then
        if [[ "$INPROGRESS_VM" == true ]]; then
            log "INFO" "===Detach Volume==="
            if ! incus storage volume detach "$STORAGE_POOL" "$AUTH_VOLUME" "$VM_NAME" "$AUTH_DEVICE" "$AUTH_MOUNT"; then
                error "Failed to detach volume."
            fi
        fi
        log "INFO" "===Delete VM==="
        if ! incus delete "$VM_NAME"; then
            error "Failed to delete VM."
        fi
    fi

}
trap rollback EXIT

# Check VM prerequiies
log "INFO" "===Phase0: Check prerequiies==="

if incus info "$VM_NAME" > /dev/null 2>&1; then
    error "Instance '$VM_NAME' aleady exists."
    exit 1
fi

if ! incus storage volume show "$STORAGE_POOL" "$AUTH_VOLUME" > /dev/null 2>&1; then
    error "Volume '$AUTH_VOLUME' does not exist."
    exit 1
fi

if ! incus network show "$NETWORK" >/dev/null 2>&1; then
    error "Error: network '$NETWORK' does not exist."
    error "Run ./scripts/setup-network.sh first."
    exit 1
fi

if ! incus network acl show "$ACL" >/dev/null 2>&1; then
    error "Error: ACL '$ACL' does not exist."
    error "Run ./scripts/setup-network.sh first."
    exit 1
fi

if [[ ! -x "$SETUP_PROXY" ]]; then
    error "Proxy setup script not found or not executable: $SETUP_PROXY"
    exit 1
fi

if [[ ! -x "$SET_PROXY_MODE" ]]; then
    error "Proxy mode script not found or not executable: $SET_PROXY_MODE"
    exit 1
fi

if ! command -v squid >/dev/null 2>&1; then
    error "Squid is not installed on the host."
    exit 1
fi

log "INFO" "===Phase1: Setup HTTP proxy==="

"$SETUP_PROXY"

log "INFO" "===Phase2: Switch proxy to provisioning mode==="

"$SET_PROXY_MODE" provisioning
PROXY_PROVISIONING=true

# Create VM
log "INFO" "===Phase3: Create Archlinux VM==="

incus launch "$IMAGE" "$VM_NAME" --vm --no-profiles < "$VM_CONFIG"

# Wait VM launch
for _ in $(seq 1 60); do
    if incus exec "$VM_NAME" -- true > /dev/null 2>&1; then
        break
    fi
    sleep 1
done
INPROGRESS_VM=true

if ! incus exec "$VM_NAME" -- true > /dev/null 2>&1;then
    error "VM did not become ready."
    exit 1
fi

# Copy mirrorlist and bootstrap to VM
log "INFO" "===Phase4: Install Mirrorlist and Bootstrap==="

incus file push "$BOOTSTRAP" "$VM_NAME/root/bootstrap.sh"
incus file push "$MIRRORLIST" "$VM_NAME/etc/pacman.d/mirrorlist"

incus exec "$VM_NAME" -- chmod 700 /root/bootstrap.sh

# Bootstrapping
log "INFO" "===Phase5: Bootstrapping==="

incus exec "$VM_NAME" -- /root/bootstrap.sh

# Copy codex-wrapper
log "INFO" "===Phase6: Install Codex wrapper"
incus exec "$VM_NAME" -- mkdir -p /home/dev/.local/bin/
incus exec "$VM_NAME" -- chown -R dev:dev /home/dev/.local
incus file push "$WRAPPER" "$VM_NAME/home/dev/.local/bin/codex"

incus exec "$VM_NAME" -- chown dev:dev /home/dev/.local/bin/codex
incus exec "$VM_NAME" -- chmod 755 /home/dev/.local/bin/codex

# Attach Volume
log "INFO" "===Phase7: Attach volume==="

incus stop "$VM_NAME"

incus storage volume attach "$STORAGE_POOL" "$AUTH_VOLUME" "$VM_NAME" "$AUTH_DEVICE" "$AUTH_MOUNT"
INPROGRESS_VOLUME=true

incus start "$VM_NAME"

for _ in $(seq 1 60); do
    if incus exec "$VM_NAME" -- true >/dev/null 2>&1; then
        break
    fi

    sleep 1
done

if ! incus exec "$VM_NAME" -- true > /dev/null 2>&1;then
    error "VM did not become ready."
    exit 1
fi
log "INFO" "===Phase8: Switch proxy to runtime mode==="

"$SET_PROXY_MODE" runtime
PROXY_PROVISIONING=false

log "INFO" "===VM created successfully.==="

INPROGRESS_VM=false
INPROGRESS_VOLUME=false
trap - EXIT

incus list "$VM_NAME"

