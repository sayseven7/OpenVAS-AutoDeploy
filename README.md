<div align="center">

# OpenVAS AutoDeploy

**Automated deployment of Greenbone Community Edition (OpenVAS) using Docker**

[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows-blue?style=flat-square)](https://github.com/sayseven7/OpenVAS-AutoDeploy)
[![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)
[![Docker](https://img.shields.io/badge/requires-Docker-2496ED?style=flat-square&logo=docker&logoColor=white)](https://www.docker.com/)
[![Greenbone](https://img.shields.io/badge/Greenbone-Community%20Edition-4CB748?style=flat-square)](https://www.greenbone.net/)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen?style=flat-square)](CONTRIBUTING.md)

One-command deployment of a full vulnerability scanning platform — no manual configuration required.

</div>

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Repository Structure](#repository-structure)
- [Quick Start — Linux](#quick-start--linux)
- [Quick Start — Windows](#quick-start--windows)
- [Feed Synchronisation](#feed-synchronisation)
- [Management Scripts](#management-scripts)
- [Screenshots](#screenshots)
- [Troubleshooting](#troubleshooting)
- [Security Notes](#security-notes)
- [Architecture & Future Roadmap](#architecture--future-roadmap)
- [Contributing](#contributing)
- [Author](#author)
- [License](#license)

---

## Overview

**OpenVAS AutoDeploy** automates the complete setup of [Greenbone Community Edition](https://www.greenbone.net/en/community-edition/) — the open-source vulnerability scanning platform — using Docker Compose v2. It handles everything from dependency installation to container orchestration, so you can focus on scanning, not setup.

Supported platforms:

| Platform | Script language | Status |
|---|---|---|
| Ubuntu 22.04 / 24.04 | Bash | ✅ Stable |
| Debian 11 / 12 | Bash | ✅ Best-effort |
| Windows 10 (20H1+) | PowerShell | ✅ Stable |
| Windows 11 | PowerShell | ✅ Stable |

---

## Features

### Linux
- Validates OS, architecture, RAM, and disk before installing
- Installs Docker Engine + Compose plugin from the official Docker repository
- Adds current user to the `docker` group automatically
- Downloads the latest official `compose.yaml` from Greenbone
- Pulls and starts all containers in detached mode
- Optional: sets a custom admin password at deploy time
- Feed synchronisation monitor with real-time log filtering
- Colour-coded output with timestamped log file

### Windows
- Full pre-flight checks: Windows version, Hyper-V, RAM, disk
- Installs Docker Desktop automatically (via `winget` or direct download)
- Waits for Docker Desktop to become responsive before proceeding
- Downloads and deploys Greenbone via Docker Compose v2
- PowerShell module architecture — shared functions across all scripts
- Feed synchronisation monitor with colour-coded, keyword-filtered output
- Optional custom admin password at deploy time
- Compatible with PowerShell 5.1 and PowerShell 7+

---

## Requirements

### Linux

| Requirement | Minimum | Recommended |
|---|---|---|
| OS | Ubuntu 22.04 / Debian 11 | Ubuntu 24.04 |
| CPU | 2 cores | 4+ cores |
| RAM | 4 GB | 8 GB |
| Disk | 15 GB free | 30 GB free |
| Network | Internet access | — |
| Privileges | `sudo` | — |

### Windows

| Requirement | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 Build 19041 (20H1) | Windows 11 |
| CPU | 2 cores (VT-x/AMD-V enabled) | 4+ cores |
| RAM | 4 GB | 8 GB |
| Disk | 20 GB free | 30 GB free |
| Network | Internet access | — |
| Privileges | Administrator | — |
| BIOS | Virtualisation enabled | — |

> **Note:** Greenbone Community Edition requires hardware virtualisation (Intel VT-x or AMD-V) to be enabled in BIOS/UEFI on Windows (for WSL2 / Hyper-V back-end).

---

## Repository Structure

```
OpenVAS-AutoDeploy/
│
├── linux/                          # Linux (Ubuntu/Debian) scripts
│   ├── lib/
│   │   └── common.sh               # Shared variables, colours, helper functions
│   ├── install.sh                  # Main installer — run this first
│   ├── start.sh                    # Start containers
│   ├── stop.sh                     # Stop containers
│   ├── status.sh                   # Container health overview
│   ├── logs.sh                     # Follow live container logs
│   ├── sync_status.sh              # Feed synchronisation monitor
│   ├── change_password.sh          # Update GVM admin password
│   └── uninstall.sh                # Full removal
│
├── windows/                        # Windows 10/11 PowerShell scripts
│   ├── modules/
│   │   └── Common.psm1             # Shared PowerShell module
│   ├── Install-Greenbone.ps1       # Main installer — run this first
│   ├── Start-Greenbone.ps1         # Start containers
│   ├── Stop-Greenbone.ps1          # Stop containers
│   ├── Get-Status.ps1              # Container health overview
│   ├── Get-Logs.ps1                # Follow live container logs
│   ├── Watch-FeedSync.ps1          # Feed synchronisation monitor
│   ├── Set-AdminPassword.ps1       # Update GVM admin password
│   └── Uninstall-Greenbone.ps1     # Full removal
│
├── screenshots/                    # Documentation images
│   ├── install.png
│   ├── feed-sync.png
│   └── dashboard-ready.png
│
├── CONTRIBUTING.md
└── README.md
```

---

## Quick Start — Linux

### 1. Clone the repository

```bash
git clone https://github.com/sayseven7/OpenVAS-AutoDeploy
cd OpenVAS-AutoDeploy/linux
chmod +x *.sh
```

### 2. Run the installer

```bash
sudo ./install.sh
```

To set a custom admin password at deploy time:

```bash
sudo GVM_ADMIN_PASSWORD='MyStr0ngP@ss!' ./install.sh
```

### 3. Access the web interface

```
https://127.0.0.1
```

Default credentials: `admin` / `admin`

> **The first feed sync takes 20–40 minutes.** The web UI will show a "Feed syncing" notice until it completes. This is expected behaviour — scans become available after sync finishes.

---

## Quick Start — Windows

### 1. Clone the repository

```powershell
git clone https://github.com/sayseven7/OpenVAS-AutoDeploy
cd OpenVAS-AutoDeploy\windows
```

### 2. Allow script execution (once per machine)

Open PowerShell **as Administrator** and run:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

If the files were downloaded via browser, cloned through GitHub Desktop, or synced via OneDrive, Windows marks them as "downloaded from the internet" and blocks execution. Unblock them with:

```powershell
# Run inside the windows\ folder
Get-ChildItem -Recurse -Filter "*.ps1"  | Unblock-File
Get-ChildItem -Recurse -Filter "*.psm1" | Unblock-File
```

### 3. Run the installer

```powershell
# Right-click PowerShell → Run as Administrator
.\Install-Greenbone.ps1
```

With a custom admin password:

```powershell
.\Install-Greenbone.ps1 -AdminPassword 'MyStr0ngP@ss!'
```

If Docker Desktop is already installed:

```powershell
.\Install-Greenbone.ps1 -SkipDockerInstall
```

Custom deployment directory:

```powershell
.\Install-Greenbone.ps1 -DeployDir 'D:\greenbone'
```

### 4. Access the web interface

```
https://127.0.0.1
```

Default credentials: `admin` / `admin`

> Accept the self-signed certificate warning in your browser.

---

## Feed Synchronisation

Greenbone requires downloading its vulnerability databases (NVT, CVE, CERT, SCAP) before scans are fully effective. This happens automatically on first startup.

### Linux — Monitor sync progress

```bash
# Real-time (default)
./sync_status.sh

# Summary snapshot
./sync_status.sh --summary

# All container logs
./sync_status.sh --all

# Custom path
./sync_status.sh --path /custom/dir
```

### Windows — Monitor sync progress

```powershell
# Real-time (default)
.\Watch-FeedSync.ps1

# Summary snapshot
.\Watch-FeedSync.ps1 -Mode Summary

# All container logs
.\Watch-FeedSync.ps1 -Mode All
```

### Sync completion indicators

| Log message | Meaning |
|---|---|
| `Finished loading VTs` | Scanner plugins fully loaded |
| `Updating ... nvdcve` | CVE feed still syncing (normal) |
| Web UI: feed banner gone | Sync complete — full scans available |

---

## Management Scripts

### Linux

| Script | Description |
|---|---|
| `./install.sh` | Full installation (run once) |
| `./start.sh` | Start containers |
| `./stop.sh` | Stop containers |
| `./status.sh` | Show container status |
| `./logs.sh [service]` | Follow live logs |
| `./sync_status.sh` | Monitor feed synchronisation |
| `./change_password.sh 'NewPass'` | Update admin password |
| `./uninstall.sh` | Remove all containers and data |

### Windows

| Script | Description |
|---|---|
| `.\Install-Greenbone.ps1` | Full installation (run once) |
| `.\Start-Greenbone.ps1` | Start containers |
| `.\Stop-Greenbone.ps1` | Stop containers |
| `.\Get-Status.ps1` | Show container status |
| `.\Get-Logs.ps1 [-Service name]` | Follow live logs |
| `.\Watch-FeedSync.ps1` | Monitor feed synchronisation |
| `.\Set-AdminPassword.ps1 -Password 'New'` | Update admin password |
| `.\Uninstall-Greenbone.ps1` | Remove all containers and data |

---

## Screenshots

### Deployment

![Deployment](screenshots/install.png)

Automated download and container preparation using Docker Compose.

---

### Feed Synchronisation

![Feed Sync](screenshots/feed-sync.png)

Initial feed loading phase where Greenbone imports CVEs, CERTs, and scanner plugins.

---

### Operational Dashboard

![Dashboard Ready](screenshots/dashboard-ready.png)

Environment fully operational — NVT database loaded, scans available.

---

## Troubleshooting

### Linux

**Docker permission denied after install**

```bash
# Log out and back in, then test with:
docker ps
# If still failing:
newgrp docker
```

**Containers keep restarting**

```bash
./logs.sh gvmd          # check gvmd logs
./logs.sh ospd-openvas  # check scanner logs
```

**Web UI shows "Feed syncing" indefinitely**

```bash
./sync_status.sh --summary
# Check if sync messages are still appearing. Sync can take up to 40 min on first run.
```

**Not on Ubuntu — script fails OS check**

The check is informational. The container workflow works on most Linux distros with Docker:

```bash
# Skip the check by setting the variable
export FORCE=1
sudo ./install.sh
# Or install Docker manually and just run:
docker compose -f ~/greenbone-community-container/compose.yaml up -d
```

---

### Windows

**`Set-ExecutionPolicy` — script blocked**

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Script is not digitally signed — files from OneDrive / GitHub Desktop / browser download**

Windows marks files downloaded from the internet with a Zone identifier that blocks `RemoteSigned` scripts without a digital signature. Unblock all scripts first:

```powershell
# Run inside the windows\ folder
Get-ChildItem -Recurse -Filter "*.ps1"  | Unblock-File
Get-ChildItem -Recurse -Filter "*.psm1" | Unblock-File
```

Then retry `.\Install-Greenbone.ps1`.

**Docker Desktop won't start — virtualisation error**

1. Restart your machine and enter BIOS/UEFI
2. Enable Intel VT-x (Intel) or AMD-V / SVM (AMD)
3. Save and reboot
4. Open Docker Desktop and enable WSL2 back-end

**`winget` not available**

Install [App Installer from the Microsoft Store](https://apps.microsoft.com/store/detail/app-installer/9NBLGGH4NNS1), or let the script fall back to the direct Docker Desktop download automatically.

**Containers start but web UI is unreachable**

```powershell
# Check container status
.\Get-Status.ps1

# Check Windows Firewall
# Ensure ports 80 and 443 are not blocked for Docker Desktop

# View logs for errors
.\Get-Logs.ps1 -Service gsad
```

**`gvmd` container reports password error during install**

gvmd initialises asynchronously. Wait for it to be fully running then retry:

```powershell
.\Set-AdminPassword.ps1 -Password 'MyNewPassword'
```

---

## Security Notes

> This project deploys a vulnerability scanner — handle it responsibly.

- **Change the default password immediately** after first login (`admin` / `admin`).
- The web interface binds to `127.0.0.1` by default (loopback only). Do not expose it to untrusted networks without additional hardening (reverse proxy + TLS + authentication).
- The self-signed TLS certificate is generated automatically. For production use, replace it with a certificate from a trusted CA.
- Greenbone scans are intrusive by nature. Only scan systems you own or have explicit written permission to test.
- Keep the host system and Docker Engine updated to receive security patches.
- Review Greenbone's [hardening guide](https://greenbone.github.io/docs/latest/) before deploying in production environments.

---

## Architecture & Future Roadmap

### Current Architecture

```
[User script]
      │
      ├─ lib/common.sh / modules/Common.psm1   ← shared logic
      │
      ├─ install / deploy scripts              ← orchestration
      │
      └─ docker compose -f compose.yaml        ← Greenbone containers
               │
               ├── gvmd          (vulnerability manager daemon)
               ├── gsad          (Greenbone Security Assistant web UI)
               ├── ospd-openvas  (OSP scanner daemon)
               ├── openvas       (OpenVAS scanner engine)
               ├── notus-scanner (local security checks)
               ├── pg-gvm        (PostgreSQL database)
               ├── redis         (message broker)
               └── vulnerability-tests (NVT feed)
```

### Suggested Future Improvements

| Idea | Notes |
|---|---|
| **macOS support** | Docker Desktop on macOS + Bash scripts (similar to Linux flow) |
| **Ansible playbook** | Idempotent cross-platform deployment for teams |
| **Scheduled feed updates** | Cron / Task Scheduler job to keep feeds current |
| **Email notifications** | Alert when sync completes or scan finishes |
| **Backup/restore scripts** | Export/import scan results and policies |
| **Reverse proxy config** | Nginx / Caddy template for public exposure with proper TLS |
| **CI/CD testing** | GitHub Actions pipeline to validate scripts on each push |
| **ARM64 Linux** | Raspberry Pi / Oracle Cloud ARM instances |

---

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Quick steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/your-feature`
3. Commit your changes following [Conventional Commits](https://www.conventionalcommits.org/)
4. Open a Pull Request

Please open an issue before starting large changes.

---

## Author

**Lucas Morais** — SaySeven / [@sayseven7](https://github.com/sayseven7)

---

## License

[MIT](LICENSE) — free for personal and commercial use.
