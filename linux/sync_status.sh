#!/usr/bin/env bash
# =============================================================================
# OpenVAS AutoDeploy — Feed Synchronisation Monitor
# Author : Lucas Morais (SaySeven / @sayseven7)
#
# Tracks Greenbone NVT/CVE/CERT feed sync progress.
#
# Usage:
#   ./sync_status.sh                  — follow sync logs in real time (default)
#   ./sync_status.sh --summary        — one-shot status summary
#   ./sync_status.sh --all            — follow ALL container logs
#   ./sync_status.sh --path /dir      — specify compose directory
#   ./sync_status.sh --help
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Override COMPOSE_FILE if --path is given (handled below before sourcing is done)
CUSTOM_PATH=""
MODE="follow"

# Sync-relevant log patterns
SYNC_PATTERN='sync|updating|finished|loaded|vt|nvt|cert|cve|cpe|scap|feed|error|warn'

# ---------------------------------------------------------------------------
print_usage() {
  cat <<'EOF'
Usage:
  ./sync_status.sh [options]

Options:
  -f, --follow        Stream sync-related log lines in real time (default)
  -s, --summary       One-shot: container status + recent sync messages
  -a, --all           Stream ALL container logs (no filter)
  -p, --path PATH     Directory containing compose.yaml
  -h, --help          Show this help

Examples:
  ./sync_status.sh
  ./sync_status.sh --summary
  ./sync_status.sh --all
  ./sync_status.sh --path /root/greenbone-community-container
EOF
}

# ---------------------------------------------------------------------------
find_compose_file() {
  local custom="${1:-}"

  if [[ -n "$custom" ]]; then
    for name in compose.yaml docker-compose.yml docker-compose.yaml; do
      [[ -f "$custom/$name" ]] && { COMPOSE_FILE="$custom/$name"; return 0; }
    done
    die "compose.yaml not found in: $custom"
  fi

  # Already set via common.sh — check default location first
  [[ -f "$COMPOSE_FILE" ]] && return 0

  # Fallback: search common directories
  local candidate
  candidate="$(find "$HOME" /root /opt -maxdepth 4 \
    \( -name compose.yaml -o -name docker-compose.yml \) 2>/dev/null \
    | grep -i greenbone | head -n 1 || true)"

  if [[ -n "$candidate" ]]; then
    COMPOSE_FILE="$candidate"
    return 0
  fi

  die "Greenbone compose file not found. Use --path /path/to/greenbone-community-container"
}

# ---------------------------------------------------------------------------
show_summary() {
  header "Feed Synchronisation Summary"
  info "Compose file: $COMPOSE_FILE"
  echo

  log "Container status:"
  dc ps
  echo

  log "Recent synchronisation messages:"
  dc logs --tail=400 gvmd ospd-openvas 2>/dev/null \
    | grep -Ei "$SYNC_PATTERN" \
    | tail -40 \
    || info "(no matching log lines found)"
  echo

  info "Indicators:"
  info "  • 'Finished loading VTs'        → scanner plugins ready"
  info "  • 'Updating ... nvdcve'          → CVE feed still syncing"
  info "  • Web UI: 'Feed syncing' banner  → sync still in progress"
}

follow_sync() {
  header "Feed Synchronisation — Live  (Ctrl+C to stop)"
  info "Compose file: $COMPOSE_FILE"
  info "Filter: $SYNC_PATTERN"
  echo

  # --tail=200 prints recent matching lines immediately so the screen is never
  # blank while we wait for new output. grep returns 1 when nothing matches yet,
  # and docker logs may exit non-zero; neither should abort the script under
  # 'set -euo pipefail', so we relax it for this streaming pipeline. Docker
  # errors are kept visible (no 2>/dev/null) to aid diagnosis.
  set +e +o pipefail
  dc logs -f --tail=200 gvmd ospd-openvas \
    | grep --line-buffered -Ei "$SYNC_PATTERN"
  set -e -o pipefail
}

follow_all() {
  header "All Container Logs — Live  (Ctrl+C to stop)"
  info "Compose file: $COMPOSE_FILE"
  echo
  dc logs -f
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--follow)  MODE="follow";  shift ;;
    -s|--summary) MODE="summary"; shift ;;
    -a|--all)     MODE="all";     shift ;;
    -p|--path)    CUSTOM_PATH="${2:-}"; shift 2 ;;
    -h|--help)    print_usage; exit 0 ;;
    *) warn "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

command -v docker >/dev/null 2>&1 || die "Docker not found."
find_compose_file "$CUSTOM_PATH"

case "$MODE" in
  follow)  follow_sync  ;;
  summary) show_summary ;;
  all)     follow_all   ;;
esac
