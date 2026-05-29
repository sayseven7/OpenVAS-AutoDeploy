#!/usr/bin/env bash
# =============================================================================
# OpenVAS AutoDeploy — Linux Installer
# Project : OpenVAS-AutoDeploy
# Author  : Lucas Morais (SaySeven / @sayseven7)
# License : MIT
#
# Automates the full deployment of Greenbone Community Edition (OpenVAS)
# using Docker on Ubuntu 22.04+ / Debian-compatible systems.
#
# Usage:
#   sudo ./install.sh
#   sudo GVM_ADMIN_PASSWORD='StrongPass' ./install.sh
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

SETUP_SCRIPT_URL="https://greenbone.github.io/docs/latest/_static/setup-and-start-greenbone-community-edition.sh"
GVM_ADMIN_PASSWORD="${GVM_ADMIN_PASSWORD:-}"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------

require_sudo() {
  command -v sudo >/dev/null 2>&1 || die "sudo is required but not installed."
  sudo -n true 2>/dev/null || {
    warn "sudo access required. You may be prompted for your password."
  }
}

check_os() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found — unsupported OS."
  # shellcheck disable=SC1091
  . /etc/os-release

  case "${ID:-}" in
    ubuntu)
      case "${VERSION_ID:-}" in
        22.*|24.*|26.*)
          log "Detected Ubuntu ${VERSION_ID} (${VERSION_CODENAME:-unknown})."
          ;;
        *)
          warn "Ubuntu ${VERSION_ID:-unknown} is outside the tested range (22.04/24.04/26.04)."
          warn "Continuing — Docker-based deployment is generally portable."
          ;;
      esac
      ;;
    debian)
      log "Detected Debian ${VERSION_ID:-unknown}. Continuing with best-effort support."
      ;;
    *)
      warn "Detected OS: ${ID:-unknown}. This script targets Ubuntu/Debian."
      warn "Proceeding — container workflow may still work on compatible systems."
      ;;
  esac
}

check_architecture() {
  local arch
  arch="$(uname -m)"
  case "$arch" in
    x86_64|amd64) log "Architecture: x86_64 — fully supported." ;;
    aarch64|arm64) log "Architecture: arm64 — community-supported." ;;
    *) warn "Architecture '$arch' is not officially tested. Proceeding anyway." ;;
  esac
}

check_resources() {
  local mem_kb
  mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local mem_gb=$(( mem_kb / 1024 / 1024 ))

  if (( mem_gb < 4 )); then
    warn "Available RAM: ~${mem_gb} GB. Greenbone recommends at least 4 GB."
    warn "Performance may be degraded."
  else
    log "Available RAM: ~${mem_gb} GB — OK."
  fi

  local disk_avail
  disk_avail=$(df -BG "$HOME" | awk 'NR==2 {print $4}' | tr -d 'G')
  if (( disk_avail < 20 )); then
    warn "Available disk space: ~${disk_avail} GB. Greenbone images require ~15–20 GB."
  else
    log "Available disk: ~${disk_avail} GB — OK."
  fi
}

# ---------------------------------------------------------------------------
# Installation steps
# ---------------------------------------------------------------------------

install_prereqs() {
  log "Updating package metadata..."
  sudo apt-get update -y -q

  log "Installing prerequisites (curl, gnupg, lsb-release, ca-certificates)..."
  sudo apt-get install -y -q ca-certificates curl gnupg lsb-release
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker Engine and Docker Compose plugin are already installed."
    return 0
  fi

  log "Removing legacy Docker packages (if present)..."
  for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
    sudo apt-get remove -y -q "$pkg" >/dev/null 2>&1 || true
  done

  log "Adding Docker's official APT repository..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  # shellcheck disable=SC1091
  . /etc/os-release
  printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu %s stable\n' \
    "$(dpkg --print-architecture)" "${VERSION_CODENAME}" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  sudo apt-get update -y -q
  log "Installing Docker Engine, CLI, containerd, and Compose plugin..."
  sudo apt-get install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
}

configure_docker_service() {
  log "Enabling and starting Docker service..."
  sudo systemctl enable --now docker

  if id -nG "$USER" | grep -qw docker; then
    log "User '$USER' is already in the docker group."
  else
    log "Adding '$USER' to the docker group..."
    sudo usermod -aG docker "$USER"
    warn "Group membership updated. You may need to log out and back in for non-sudo Docker access."
  fi
}

optimize_docker_daemon() {
  local daemon_cfg="/etc/docker/daemon.json"

  # Skip if already configured by the user
  if [[ -f "$daemon_cfg" ]]; then
    log "Docker daemon config already exists at $daemon_cfg — skipping optimisation."
    return 0
  fi

  log "Configuring Docker daemon for faster image pulls..."
  sudo tee "$daemon_cfg" >/dev/null <<'EOF'
{
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 10
}
EOF

  sudo systemctl restart docker
  log "Docker daemon optimised (parallel downloads: 10)."
}

prepare_directory() {
  mkdir -p "$DOWNLOAD_DIR"
  log "Deployment directory: $DOWNLOAD_DIR"
}

download_compose() {
  log "Downloading official Greenbone compose.yaml..."
  curl -fsSL "$COMPOSE_URL" -o "$COMPOSE_FILE"
  log "Saved to: $COMPOSE_FILE"
}

pull_and_start() {
  log "Pulling Greenbone Community Edition container images (this may take several minutes)..."
  docker compose -f "$COMPOSE_FILE" pull

  log "Starting all containers in detached mode..."
  docker compose -f "$COMPOSE_FILE" up -d
}

set_admin_password() {
  if [[ -z "$GVM_ADMIN_PASSWORD" ]]; then
    warn "GVM_ADMIN_PASSWORD not set. The default 'admin/admin' credentials will remain active."
    warn "Change it later: ./change_password.sh 'NewStrongPassword'"
    return 0
  fi

  log "Waiting 15 seconds for gvmd to initialise before updating password..."
  sleep 15

  if docker compose -f "$COMPOSE_FILE" exec -u gvmd gvmd \
      gvmd --user=admin --new-password="$GVM_ADMIN_PASSWORD" 2>/dev/null; then
    log "Admin password updated successfully."
  else
    warn "Password update failed at this stage (gvmd may still be initialising)."
    warn "Retry later: ./change_password.sh '$GVM_ADMIN_PASSWORD'"
  fi
}

print_summary() {
  header "Deployment Complete"

  cat <<EOF

  Deployment directory : $DOWNLOAD_DIR
  Log file             : $LOG_FILE

  Web Interface:
    https://127.0.0.1
    https://127.0.0.1:9392

  Default credentials (change immediately!):
    Username : admin
    Password : admin  ← or your custom GVM_ADMIN_PASSWORD

  Management scripts:
    ./status.sh                         — container health
    ./logs.sh                           — live container logs
    ./sync_status.sh                    — feed synchronisation monitor
    ./stop.sh                           — stop all containers
    ./start.sh                          — start containers
    ./change_password.sh 'NewPass'      — update admin password
    ./uninstall.sh                      — full removal

  Notes:
    • First feed synchronisation takes 20–40 minutes.
    • The web UI may show "Feed is currently syncing" — this is expected.
    • If Docker access requires sudo in your current shell, log out and log in again.

EOF
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
  header "OpenVAS AutoDeploy — Linux Installer"

  require_sudo
  check_os
  check_architecture
  check_resources
  install_prereqs
  install_docker
  configure_docker_service
  optimize_docker_daemon
  prepare_directory
  download_compose
  pull_and_start
  set_admin_password
  print_summary
}

main "$@"
