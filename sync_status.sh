#!/usr/bin/env bash
# Author: Lucas Morais (SaySeven / @sayseven7)
# Project: Openvas-Seven
# Purpose: Follow Greenbone/OpenVAS feed synchronization logs.

set -euo pipefail

PROJECT_NAME="greenbone-community-container"
DEFAULT_DIRS=(
  "$HOME/$PROJECT_NAME"
  "/root/$PROJECT_NAME"
  "/opt/$PROJECT_NAME"
  "$(pwd)/$PROJECT_NAME"
)

COMPOSE_FILE=""

print_usage() {
  cat <<'EOF'
Usage:
  ./sync_status.sh [options]

Options:
  -f, --follow        Follow sync logs in real time (default)
  -s, --summary       Show container status and recent sync messages
  -a, --all           Show all Greenbone container logs
  -p, --path PATH     Path to directory containing compose.yaml
  -h, --help          Show this help

Examples:
  ./sync_status.sh
  ./sync_status.sh --summary
  ./sync_status.sh --all
  ./sync_status.sh --path /root/greenbone-community-container
EOF
}

find_compose_file() {
  local custom_path="${1:-}"

  if [[ -n "$custom_path" ]]; then
    if [[ -f "$custom_path/compose.yaml" ]]; then
      COMPOSE_FILE="$custom_path/compose.yaml"
      return 0
    fi

    if [[ -f "$custom_path/docker-compose.yml" ]]; then
      COMPOSE_FILE="$custom_path/docker-compose.yml"
      return 0
    fi

    echo "[!] compose.yaml not found in: $custom_path"
    exit 1
  fi

  for dir in "${DEFAULT_DIRS[@]}"; do
    if [[ -f "$dir/compose.yaml" ]]; then
      COMPOSE_FILE="$dir/compose.yaml"
      return 0
    fi

    if [[ -f "$dir/docker-compose.yml" ]]; then
      COMPOSE_FILE="$dir/docker-compose.yml"
      return 0
    fi
  done

  local found=""
  found="$(find "$HOME" /root /opt -maxdepth 3 \( -name compose.yaml -o -name docker-compose.yml \) 2>/dev/null | grep -i greenbone | head -n 1 || true)"

  if [[ -n "$found" ]]; then
    COMPOSE_FILE="$found"
    return 0
  fi

  echo "[!] Greenbone compose file not found."
  echo "    Try: ./sync_status.sh --path /path/to/greenbone-community-container"
  exit 1
}

docker_compose() {
  docker compose -f "$COMPOSE_FILE" "$@"
}

show_header() {
  echo "[+] Using compose file: $COMPOSE_FILE"
  echo
}

show_summary() {
  show_header

  echo "[+] Container status:"
  docker_compose ps
  echo

  echo "[+] Recent synchronization messages:"
  docker_compose logs --tail=300 gvmd ospd-openvas 2>/dev/null | grep -Ei "sync|updating|finished|loaded|vt|nvt|cert|cve|cpe|scap|feed" || true
  echo

  echo "[+] Useful indicators:"
  echo "    - 'Finished loading VTs' means scanner plugins were loaded."
  echo "    - Repeated 'Updating ... nvdcve' means CVE feed sync is still running."
  echo "    - The web UI warning 'Feed is currently syncing' disappears when sync completes."
}

follow_sync_logs() {
  show_header

  echo "[+] Following feed synchronization logs..."
  echo "    Press Ctrl+C to stop."
  echo

  docker_compose logs -f gvmd ospd-openvas 2>/dev/null | grep --line-buffered -Ei "sync|updating|finished|loaded|vt|nvt|cert|cve|cpe|scap|feed|error|warning"
}

follow_all_logs() {
  show_header

  echo "[+] Following all Greenbone container logs..."
  echo "    Press Ctrl+C to stop."
  echo

  docker_compose logs -f
}

MODE="follow"
CUSTOM_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f|--follow)
      MODE="follow"
      shift
      ;;
    -s|--summary)
      MODE="summary"
      shift
      ;;
    -a|--all)
      MODE="all"
      shift
      ;;
    -p|--path)
      CUSTOM_PATH="${2:-}"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "[!] Unknown option: $1"
      print_usage
      exit 1
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "[!] Docker is not installed or not available in PATH."
  exit 1
fi

find_compose_file "$CUSTOM_PATH"

case "$MODE" in
  follow)
    follow_sync_logs
    ;;
  summary)
    show_summary
    ;;
  all)
    follow_all_logs
    ;;
esac
