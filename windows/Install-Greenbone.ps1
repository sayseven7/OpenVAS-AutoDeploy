#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Automates the full deployment of Greenbone Community Edition (OpenVAS) on Windows.

.DESCRIPTION
    This script:
      1. Validates system requirements (Windows version, RAM, disk, virtualisation)
      2. Installs Docker Desktop if not present (via winget or direct download)
      3. Waits for Docker Desktop to become ready
      4. Downloads the official Greenbone compose.yaml
      5. Pulls and starts all Greenbone containers
      6. Optionally sets a custom admin password
      7. Displays a deployment summary

.PARAMETER AdminPassword
    Optional. Custom password for the GVM admin account.
    If omitted, the default 'admin / admin' credentials remain active.
    Change it after deployment with Set-AdminPassword.ps1.

.PARAMETER DeployDir
    Optional. Directory where the compose.yaml and data volumes are stored.
    Default: %USERPROFILE%\greenbone-community-container

.PARAMETER SkipDockerInstall
    Optional. Skip Docker Desktop installation (use if already installed).

.EXAMPLE
    # Standard deployment (interactive)
    .\Install-Greenbone.ps1

.EXAMPLE
    # Deployment with custom admin password
    .\Install-Greenbone.ps1 -AdminPassword 'MyStr0ngP@ss!'

.EXAMPLE
    # Custom deploy directory, Docker already installed
    .\Install-Greenbone.ps1 -DeployDir 'D:\greenbone' -SkipDockerInstall

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
    Requires: Windows 10 20H1 (Build 19041) or Windows 11
              PowerShell 5.1+ (or PowerShell 7+)
              Administrator privileges
              Internet access
#>

[CmdletBinding()]
param(
    [string] $AdminPassword    = '',
    [string] $DeployDir        = '',
    [switch] $SkipDockerInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Bootstrap -- load shared module
# ---------------------------------------------------------------------------
$ModulePath = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (-not (Test-Path $ModulePath)) {
    Write-Error "Cannot find Common.psm1 at '$ModulePath'. Ensure the modules\ folder is present."
    exit 1
}
Import-Module $ModulePath -Force

# Apply optional parameter overrides
if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
    $Global:OVAConfig.LogFile     = Join-Path $DeployDir 'openvas-autodeploy.log'
}

# Ensure deploy dir exists for logging
$null = New-Item -ItemType Directory -Path $Global:OVAConfig.DeployDir -Force

# ---------------------------------------------------------------------------
# Step 1 -- Pre-flight validation
# ---------------------------------------------------------------------------
function Invoke-PreFlight {
    Write-Header 'Pre-flight System Check'

    Assert-Administrator
    Assert-WindowsVersion
    Assert-Virtualization
    Assert-SystemResources
}

# ---------------------------------------------------------------------------
# Step 2 -- Docker Desktop installation
# ---------------------------------------------------------------------------
function Install-DockerDesktop {
    if (Test-DockerInstalled) {
        Write-Log 'Docker Desktop is already installed.' -Level Success

        if (-not (Test-DockerRunning)) {
            Write-Log 'Docker Desktop is installed but not running. Attempting to start...' -Level Warning
            Start-DockerDesktop
            Wait-DockerReady
        }
        return
    }

    Write-Log 'Docker Desktop not found. Attempting installation...' -Level Info

    # Try winget first (available on Windows 10 1809+ with App Installer)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Log 'Installing Docker Desktop via winget...' -Level Info
        try {
            winget install --id Docker.DockerDesktop --accept-source-agreements --accept-package-agreements --silent
            if ($LASTEXITCODE -eq 0) {
                Write-Log 'Docker Desktop installed via winget.' -Level Success
                Update-SessionPath
                Start-DockerDesktop
                Wait-DockerReady -TimeoutSeconds $Global:OVAConfig.DockerFirstStartTimeoutSec
                return
            }
        } catch {
            Write-Log 'winget installation failed. Falling back to direct download.' -Level Warning
        }
    }

    # Fallback: direct installer download
    $installerPath = Join-Path $env:TEMP 'DockerDesktopInstaller.exe'
    Write-Log 'Downloading Docker Desktop installer...' -Level Info
    Write-Log "Source: $($Global:OVAConfig.DockerDesktopUrl)" -Level Dim

    try {
        $client = New-Object System.Net.WebClient
        $client.DownloadFile($Global:OVAConfig.DockerDesktopUrl, $installerPath)
    } catch {
        Exit-WithError "Failed to download Docker Desktop installer: $_"
    }

    Write-Log 'Running Docker Desktop installer (silent)...' -Level Info
    Write-Log 'This may take several minutes. Please wait.' -Level Dim

    $proc = Start-Process -FilePath $installerPath -ArgumentList 'install', '--quiet', '--accept-license' -Wait -PassThru
    if ($proc.ExitCode -notin @(0, 1)) {
        Exit-WithError "Docker Desktop installer exited with code $($proc.ExitCode). Check Windows Event Viewer."
    }

    Write-Log 'Docker Desktop installation completed.' -Level Success
    Remove-Item $installerPath -Force -ErrorAction SilentlyContinue

    Update-SessionPath
    Start-DockerDesktop
    Wait-DockerReady -TimeoutSeconds $Global:OVAConfig.DockerFirstStartTimeoutSec
}

function Start-DockerDesktop {
    $desktopExe = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if ($desktopExe) {
        Write-Log 'Launching Docker Desktop...' -Level Info
        # Do NOT hide the window: on a first-time install Docker Desktop may show
        # a service-agreement / setup dialog that the user must accept before the
        # engine starts. A hidden window would block the deployment indefinitely.
        Start-Process -FilePath $desktopExe
        Write-Log 'If Docker Desktop shows a first-run setup or license prompt, accept it.' -Level Dim
        Start-Sleep -Seconds 10
    } else {
        Write-Log 'Docker Desktop executable not found in standard locations. Start it manually if needed.' -Level Warning
    }
}

# ---------------------------------------------------------------------------
# Step 3 -- Deploy Greenbone
# ---------------------------------------------------------------------------
function Initialize-DeploymentDirectory {
    Write-Log "Deployment directory: $($Global:OVAConfig.DeployDir)" -Level Info
    $null = New-Item -ItemType Directory -Path $Global:OVAConfig.DeployDir -Force
}

function Get-GreenboneCompose {
    Write-Log 'Downloading official Greenbone compose.yaml...' -Level Info

    try {
        Invoke-WebRequest -Uri $Global:OVAConfig.ComposeUrl `
            -OutFile $Global:OVAConfig.ComposeFile `
            -UseBasicParsing
    } catch {
        Exit-WithError "Failed to download compose.yaml: $_"
    }

    Write-Log "Saved: $($Global:OVAConfig.ComposeFile)" -Level Success
}

function Start-GreenboneContainers {
    Write-Log 'Pulling Greenbone container images (this may take 10-20 minutes on first run)...' -Level Info
    Write-Log 'Images: gvmd, gsad, ospd-openvas, notus-scanner, openvas-scanner, redis, pg-gvm, vulnerability-tests' -Level Dim

    Invoke-DockerCompose @('pull')

    # Data containers (scap-data, cert-bund-data, ...) load their datasets into
    # PostgreSQL and can fail their healthcheck on the very first boot if pg-gvm
    # is still initialising. The data already lands in the volumes, so retrying
    # 'up -d' reliably brings the stack up.
    $maxAttempts = 3
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
        Write-Log "Starting all containers in detached mode (attempt $attempt/$maxAttempts)..." -Level Info
        try {
            Invoke-DockerCompose @('up', '-d')
            Write-Log 'All containers started.' -Level Success
            return
        } catch {
            if ($attempt -lt $maxAttempts) {
                Write-Log 'A container healthcheck failed (commonly scap-data, due to first-boot timing).' -Level Warning
                Write-Log 'Retrying in 20s -- datasets are already in the volumes...' -Level Warning
                Start-Sleep -Seconds 20
            }
        }
    }

    Exit-WithError "Containers failed to start after $maxAttempts attempts. Inspect logs with: .\Get-Logs.ps1 scap-data"
}

# ---------------------------------------------------------------------------
# Step 4 -- Optional: set admin password
# ---------------------------------------------------------------------------
function Set-InitialAdminPassword {
    param([string]$Password)

    if ([string]::IsNullOrWhiteSpace($Password)) {
        Write-Log 'No custom admin password provided.' -Level Warning
        Write-Log 'Default credentials: admin / admin -- change with Set-AdminPassword.ps1' -Level Warning
        return
    }

    Write-Log 'Waiting 20 seconds for gvmd to initialise before setting password...' -Level Info
    Start-Sleep -Seconds 20

    try {
        & docker compose -f $Global:OVAConfig.ComposeFile exec -u gvmd gvmd `
            gvmd --user=admin --new-password=$Password 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Log 'Admin password configured successfully.' -Level Success
        } else {
            Write-Log 'Password update failed (gvmd may still be initialising). Retry with Set-AdminPassword.ps1' -Level Warning
        }
    } catch {
        Write-Log "Password update attempt failed: $_. Retry later with Set-AdminPassword.ps1" -Level Warning
    }
}

# ---------------------------------------------------------------------------
# Step 5 -- Summary
# ---------------------------------------------------------------------------
function Write-DeploymentSummary {
    Write-Header 'Deployment Complete'

    Write-Host ''
    Write-Host '  Web Interface:' -ForegroundColor White
    Write-Host '    https://127.0.0.1' -ForegroundColor Cyan
    Write-Host '    https://127.0.0.1:9392' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Default Credentials (change immediately):' -ForegroundColor White
    Write-Host '    Username : admin' -ForegroundColor Yellow
    Write-Host '    Password : admin  (or your -AdminPassword value)' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  Deployment Directory:' -ForegroundColor White
    Write-Host "    $($Global:OVAConfig.DeployDir)" -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Management Scripts:' -ForegroundColor White
    Write-Host '    .\Start-Greenbone.ps1           - start containers' -ForegroundColor DarkGray
    Write-Host '    .\Stop-Greenbone.ps1            - stop containers' -ForegroundColor DarkGray
    Write-Host '    .\Get-Status.ps1                - container health' -ForegroundColor DarkGray
    Write-Host '    .\Get-Logs.ps1                  - live logs' -ForegroundColor DarkGray
    Write-Host '    .\Watch-FeedSync.ps1            - monitor feed sync' -ForegroundColor DarkGray
    Write-Host '    .\Set-AdminPassword.ps1 <pass>  - change admin password' -ForegroundColor DarkGray
    Write-Host '    .\Uninstall-Greenbone.ps1       - full removal' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  Important Notes:' -ForegroundColor White
    Write-Host '    * First feed sync takes 20-40 minutes (NVT/CVE/CERT databases).' -ForegroundColor DarkGray
    Write-Host '    * The web UI shows "Feed syncing" until sync completes -- this is normal.' -ForegroundColor DarkGray
    Write-Host '    * Keep Docker Desktop running for the containers to stay active.' -ForegroundColor DarkGray
    Write-Host '    * Accept the self-signed certificate warning in your browser.' -ForegroundColor DarkGray
    Write-Host ''
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
function Main {
    Write-Header 'OpenVAS AutoDeploy -- Windows Installer'
    Write-Log "Script version: 2.0  |  Date: $(Get-Date -Format 'yyyy-MM-dd')" -Level Dim

    Invoke-PreFlight

    if (-not $SkipDockerInstall) {
        Write-Header 'Docker Desktop'
        Install-DockerDesktop
    } else {
        Write-Header 'Docker Validation'
        Assert-DockerReady
    }

    Write-Header 'Greenbone Deployment'
    Initialize-DeploymentDirectory
    Get-GreenboneCompose
    Start-GreenboneContainers
    Set-InitialAdminPassword -Password $AdminPassword

    Write-DeploymentSummary
}

Main
