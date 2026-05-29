#!/usr/bin/env bash
# OpenVAS AutoDeploy — Start Greenbone containers
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

need_running

log "Pulling latest images..."
dc pull

log "Starting Greenbone Community Edition..."
dc up -d

log "All containers started. Use ./status.sh to check health."
