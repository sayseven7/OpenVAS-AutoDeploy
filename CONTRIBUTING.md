# Contributing to OpenVAS AutoDeploy

Thank you for your interest in contributing! This document covers the process for reporting issues, proposing changes, and submitting pull requests.

---

## Getting Started

1. **Fork** the repository and clone your fork locally.
2. Create a **feature branch** from `main`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
3. Make your changes following the guidelines below.
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   ```
   feat: add macOS support
   fix: correct Docker group detection on Debian
   docs: update Windows troubleshooting section
   ```
5. Push and open a **Pull Request** against `main`.

---

## Contribution Areas

| Area | What to consider |
|---|---|
| **Linux scripts** | Test on Ubuntu 22.04 and 24.04. Follow `shellcheck` recommendations. |
| **Windows scripts** | Test on Windows 10 (Build 19041+) and Windows 11. Use `PSScriptAnalyzer`. |
| **Documentation** | Keep README sections consistent across both platforms. |
| **Bug reports** | Include OS version, Docker version, and the full error output. |

---

## Code Style

### Bash (Linux)
- Use `shellcheck` — no warnings allowed.
- Source `lib/common.sh` for shared functions; do not duplicate them.
- Use `set -Eeuo pipefail` at the top of every script.
- Prefer `log`, `warn`, `die` helpers over raw `echo`.

### PowerShell (Windows)
- Target PowerShell 5.1 minimum (avoid PS7-only cmdlets unless clearly noted).
- Import `modules\Common.psm1` for shared helpers.
- Use approved verbs (`Get-`, `Set-`, `Start-`, `Stop-`, `Watch-`, etc.).
- Run `PSScriptAnalyzer` before submitting.

---

## Reporting Issues

Please open an [issue](https://github.com/sayseven7/OpenVAS-AutoDeploy/issues) and include:

- Operating system and version
- Docker / Docker Desktop version
- The exact command you ran
- Full terminal output (use a code block)
- Any error messages from `./status.sh` or `.\Get-Status.ps1`

---

## Pull Request Checklist

- [ ] Scripts run without errors on a clean machine
- [ ] `shellcheck` passes (Linux scripts)
- [ ] `PSScriptAnalyzer` passes (Windows scripts)
- [ ] README updated if new scripts or options were added
- [ ] Commit messages follow Conventional Commits

---

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
