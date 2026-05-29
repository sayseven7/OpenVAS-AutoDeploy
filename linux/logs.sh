#!/usr/bin/env bash
# OpenVAS AutoDeploy — Follow live container logs
#
# Usage:
#   ./logs.sh              — follow all containers
#   ./logs.sh gvmd         — follow a specific service
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

need_running

SERVICE="${1:-}"

if [[ -n "$SERVICE" ]]; then
  log "Following logs for service: $SERVICE  (Ctrl+C to stop)"
  dc logs -f "$SERVICE"
else
  log "Following all container logs  (Ctrl+C to stop)"
  dc logs -f
fi
