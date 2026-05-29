#!/usr/bin/env bash
# OpenVAS AutoDeploy — Update the GVM admin password
#
# Usage: ./change_password.sh 'NewStrongPassword'
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

NEW_PASSWORD="${1:-}"
[[ -n "$NEW_PASSWORD" ]] || die "Usage: ./change_password.sh 'NewStrongPassword'"

need_running

log "Updating admin password..."
dc exec -u gvmd gvmd gvmd --user=admin --new-password="$NEW_PASSWORD"
log "Password updated. New credentials: admin / <your new password>"
