#!/usr/bin/env bash
# OpenVAS AutoDeploy — Container health status
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

need_running

header "Greenbone Community Edition — Container Status"
dc ps

printf '\n'
info "Web interface: https://127.0.0.1  |  https://127.0.0.1:9392"
info "Default credentials: admin / admin (change with ./change_password.sh)"
