#!/usr/bin/env bash
# OpenVAS AutoDeploy — Full removal of Greenbone Community Edition
#
# Stops containers, removes volumes, and optionally deletes the deployment
# directory. Docker Engine itself is NOT removed.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

need_docker

header "OpenVAS AutoDeploy — Uninstall"
warn "This will stop all containers and delete all Greenbone data (volumes)."
read -r -p "Continue? [y/N] " confirm
[[ "${confirm,,}" == "y" ]] || { info "Aborted."; exit 0; }

if [[ -f "$COMPOSE_FILE" ]]; then
  log "Stopping containers and removing volumes..."
  dc down -v || true
else
  warn "compose.yaml not found at '$COMPOSE_FILE'. Skipping container teardown."
fi

read -r -p "Delete deployment directory '$DOWNLOAD_DIR'? [y/N] " confirm_dir
if [[ "${confirm_dir,,}" == "y" ]]; then
  rm -rf "$DOWNLOAD_DIR"
  log "Removed: $DOWNLOAD_DIR"
else
  info "Deployment directory kept: $DOWNLOAD_DIR"
fi

log "Greenbone Community Edition has been removed."
info "Docker Engine was NOT uninstalled. Remove it manually if needed."
