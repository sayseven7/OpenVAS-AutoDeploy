#!/usr/bin/env bash
# Shared configuration and utility functions sourced by all Linux scripts.
# Do not execute this file directly.

# ---------------------------------------------------------------------------
# Configuration — override via environment variables before sourcing
# ---------------------------------------------------------------------------
DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/greenbone-community-container}"
COMPOSE_FILE="$DOWNLOAD_DIR/compose.yaml"
COMPOSE_URL="${COMPOSE_URL:-https://greenbone.github.io/docs/latest/_static/compose.yaml}"
LOG_FILE="${LOG_FILE:-$DOWNLOAD_DIR/openvas-autodeploy.log}"

# ---------------------------------------------------------------------------
# Colour helpers — fall back to plain text when not on a terminal
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  _GREEN='\033[0;32m'; _YELLOW='\033[0;33m'; _RED='\033[0;31m'
  _BLUE='\033[0;34m';  _BOLD='\033[1m';       _RESET='\033[0m'
else
  _GREEN=''; _YELLOW=''; _RED=''; _BLUE=''; _BOLD=''; _RESET=''
fi

# ---------------------------------------------------------------------------
# Logging functions
# ---------------------------------------------------------------------------
_ts() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
  local msg="[+] $*"
  printf "${_GREEN}%s${_RESET}\n" "$msg"
  [[ -d "$(dirname "$LOG_FILE")" ]] && printf '%s %s\n' "$(_ts)" "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
  local msg="[!] $*"
  printf "${_YELLOW}%s${_RESET}\n" "$msg" >&2
  [[ -d "$(dirname "$LOG_FILE")" ]] && printf '%s %s\n' "$(_ts)" "$msg" >> "$LOG_FILE" 2>/dev/null || true
}

die() {
  local msg="[✗] $*"
  printf "${_RED}%s${_RESET}\n" "$msg" >&2
  [[ -d "$(dirname "$LOG_FILE")" ]] && printf '%s %s\n' "$(_ts)" "$msg" >> "$LOG_FILE" 2>/dev/null || true
  exit 1
}

info() {
  printf "${_BLUE}[i]${_RESET} %s\n" "$*"
}

header() {
  printf "\n${_BOLD}%s${_RESET}\n" "$*"
  printf '%0.s─' $(seq 1 ${#*})
  printf '\n'
}

# ---------------------------------------------------------------------------
# Common guards
# ---------------------------------------------------------------------------
need_docker() {
  command -v docker >/dev/null 2>&1 || die "Docker not found. Run ./install.sh first."
  docker compose version >/dev/null 2>&1 || die "Docker Compose plugin not found. Run ./install.sh first."
}

need_compose_file() {
  [[ -f "$COMPOSE_FILE" ]] || die "compose.yaml not found at '$COMPOSE_FILE'. Run ./install.sh first."
}

need_running() {
  need_docker
  need_compose_file
}

# Convenience wrapper so every script uses the same compose invocation
dc() {
  docker compose -f "$COMPOSE_FILE" "$@"
}
