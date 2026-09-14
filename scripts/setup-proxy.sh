#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

REPO_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

SQUID_CONFIG="$REPO_DIR/squid/squid.conf"
RUNTIME_DOMAINS="$REPO_DIR/squid/domains-runtime.txt"

if [[ ! -f "$SQUID_CONFIG" ]]; then
    echo "Error: $SQUID_CONFIG not found." >&2
    exit 1
fi

if [[ ! -f "$RUNTIME_DOMAINS" ]]; then
    echo "Error: $RUNTIME_DOMAINS not found." >&2
    exit 1
fi

echo "==> Installing Squid configuration"

cp /etc/squid/squid.conf /etc/squid/squid.conf_bck

install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$SQUID_CONFIG" \
    /etc/squid/squid.conf

install \
    --owner=root \
    --group=root \
    --mode=0644 \
    "$RUNTIME_DOMAINS" \
    /etc/squid/codex-allowed-domains.txt

echo "==> Validating Squid configuration"

squid -k check
squid -k parse

echo "==> Starting Squid"

systemctl enable --now squid.service

echo "==> Proxy setup completed"
