#!/usr/bin/env bash
set -Eeuo pipefail

DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/greenbone-community-container}"
COMPOSE_FILE="$DOWNLOAD_DIR/compose.yaml"

die() {
  echo "[!] $*" >&2
  exit 1
}

need_file() {
  [[ -f "$COMPOSE_FILE" ]] || die "compose.yaml not found at $COMPOSE_FILE. Run ./Openvas_Seven.sh first."
}

need_docker() {
  command -v docker >/dev/null 2>&1 || die "docker not found."
  docker compose version >/dev/null 2>&1 || die "docker compose plugin not found."
}

need_docker
if [[ -f "$COMPOSE_FILE" ]]; then
  docker compose -f "$COMPOSE_FILE" down -v || true
fi

read -r -p "Remove deployment directory $DOWNLOAD_DIR? [y/N] " answer
if [[ "${answer,,}" == "y" ]]; then
  rm -rf "$DOWNLOAD_DIR"
  echo "[+] Removed $DOWNLOAD_DIR"
else
  echo "[*] Kept $DOWNLOAD_DIR"
fi
