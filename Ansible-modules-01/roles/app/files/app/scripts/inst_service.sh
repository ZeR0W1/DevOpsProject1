#!/bin/bash

set -euo pipefail

LOG_FILE="logs/provisioning.log"

log() {
    local message="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [service_inst] $message" | tee -a "$LOG_FILE"
}

fail() {
    local message="$1"
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [service_inst] ERROR: $message" | tee -a "$LOG_FILE" >&2
    exit 1
}

log "Service installation script started"

if ! command -v dpkg >/dev/null 2>&1; then
    fail "dpkg is not available on this system"
fi

if ! command -v apt >/dev/null 2>&1; then
    fail "apt is not available on this system"
fi

if dpkg -s nginx >/dev/null 2>&1; then
    log "nginx is already installed"
    exit 0
fi

log "installing Nginx:"
if ! sudo apt install -y nginx; then
    fail "failed to install nginx"
fi

log "nginx installation step completed"