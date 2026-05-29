#!/usr/bin/env bash
# OpenVAS AutoDeploy — Stop Greenbone containers
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

need_running

log "Stopping Greenbone Community Edition..."
dc down

log "All containers stopped."
