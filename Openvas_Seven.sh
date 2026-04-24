#!/usr/bin/env bash
# Author: Lucas Morais (SaySeven / @sayseven7)
# Project: Openvas-Seven
set -Eeuo pipefail

DOWNLOAD_DIR="${DOWNLOAD_DIR:-$HOME/greenbone-community-container}"
COMPOSE_FILE="$DOWNLOAD_DIR/compose.yaml"
SETUP_SCRIPT_URL="https://greenbone.github.io/docs/latest/_static/setup-and-start-greenbone-community-edition.sh"
COMPOSE_URL="https://greenbone.github.io/docs/latest/_static/compose.yaml"
GVM_ADMIN_PASSWORD="${GVM_ADMIN_PASSWORD:-}"

log() {
  printf '[+] %s\n' "$*"
}

warn() {
  printf '[!] %s\n' "$*" >&2
}

die() {
  printf '[!] %s\n' "$*" >&2
  exit 1
}

require_root_sudo() {
  command -v sudo >/dev/null 2>&1 || die "sudo is required."
}

check_ubuntu() {
  [[ -r /etc/os-release ]] || die "/etc/os-release not found."
  . /etc/os-release

  [[ "${ID:-}" == "ubuntu" ]] || die "This installer targets Ubuntu hosts."

  case "${VERSION_ID:-}" in
    26.*|24.*)
      log "Detected Ubuntu ${VERSION_ID} (${VERSION_CODENAME:-unknown})."
      ;;
    *)
      warn "Ubuntu ${VERSION_ID:-unknown} is not the primary target for this script."
      warn "Continuing anyway because the container workflow is usually more portable than source builds."
      ;;
  esac
}

install_prereqs() {
  log "Updating apt metadata..."
  sudo apt-get update -y

  log "Installing prerequisites..."
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
}

install_docker() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    log "Docker and Docker Compose plugin already available."
  else
    log "Removing conflicting Docker packages if present..."
    for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
      sudo apt-get remove -y "$pkg" >/dev/null 2>&1 || true
    done

    log "Configuring Docker repository..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    . /etc/os-release
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    sudo apt-get update -y
    log "Installing Docker Engine + Compose plugin..."
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  log "Enabling and starting Docker..."
  sudo systemctl enable --now docker
}

ensure_docker_access() {
  if id -nG "$USER" | grep -qw docker; then
    log "User $USER is already in docker group."
  else
    log "Adding $USER to docker group..."
    sudo usermod -aG docker "$USER"
    warn "Group membership changed. You may need to log out/in after installation."
  fi
}

prepare_download_dir() {
  mkdir -p "$DOWNLOAD_DIR"
  log "Using deployment directory: $DOWNLOAD_DIR"
}

download_latest_compose() {
  log "Downloading latest official Greenbone compose.yaml..."
  curl -f -L "$COMPOSE_URL" -o "$COMPOSE_FILE"
}

pull_and_start() {
  log "Pulling Greenbone Community Edition container images..."
  docker compose -f "$COMPOSE_FILE" pull

  log "Starting containers in background..."
  docker compose -f "$COMPOSE_FILE" up -d
}

set_admin_password() {
  if [[ -z "$GVM_ADMIN_PASSWORD" ]]; then
    warn "GVM_ADMIN_PASSWORD not provided. Default admin/admin will remain until you change it."
    warn "You can change it later with: ./change_password.sh 'NewStrongPassword'"
    return 0
  fi

  log "Waiting a bit before trying to update the admin password..."
  sleep 10

  log "Trying to update admin password..."
  docker compose -f "$COMPOSE_FILE" exec -u gvmd gvmd gvmd --user=admin --new-password="$GVM_ADMIN_PASSWORD" || \
    warn "Password update did not complete now. Try later with ./change_password.sh"
}

print_summary() {
  cat <<EOF

[+] Installation finished.

Deployment directory:
    $DOWNLOAD_DIR

Web UI:
    https://127.0.0.1
    https://127.0.0.1:9392

Default credentials (unless changed):
    user: admin
    pass: admin

Useful commands:
    ./status.sh
    ./logs.sh
    ./stop.sh
    ./start.sh
    ./change_password.sh 'NewStrongPassword'

Important:
- First feed sync can take a long time.
- If Docker access fails for your current shell, log out/in and run:
      ./start.sh

EOF
}

main() {
  require_root_sudo
  check_ubuntu
  install_prereqs
  install_docker
  ensure_docker_access
  prepare_download_dir
  download_latest_compose
  pull_and_start
  set_admin_password
  print_summary
}

main "$@"
