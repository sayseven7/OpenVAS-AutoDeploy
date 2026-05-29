# =============================================================================
# OpenVAS-AutoDeploy -- Common PowerShell Module
# Project : OpenVAS-AutoDeploy (Windows)
# Author  : Lucas Morais (SaySeven / @sayseven7)
# License : MIT
#
# Shared configuration, logging, and utility functions used by all
# Windows PowerShell scripts. Import with:
#   Import-Module "$PSScriptRoot\modules\Common.psm1"
# =============================================================================

# ---------------------------------------------------------------------------
# Configuration -- can be overridden before importing the module
# ---------------------------------------------------------------------------
$Global:OVAConfig = @{
    DeployDir       = Join-Path $env:USERPROFILE 'greenbone-community-container'
    ComposeUrl      = 'https://greenbone.github.io/docs/latest/_static/compose.yaml'
    ComposeFile     = ''          # resolved at runtime
    DockerDesktopUrl = 'https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe'
    LogFile         = ''          # resolved at runtime
    MinRamGB        = 4
    MinDiskGB       = 20
    DockerStartupTimeoutSec = 120
}

$Global:OVAConfig.ComposeFile = Join-Path $Global:OVAConfig.DeployDir 'compose.yaml'
$Global:OVAConfig.LogFile     = Join-Path $Global:OVAConfig.DeployDir 'openvas-autodeploy.log'

# ---------------------------------------------------------------------------
# Colour palette
# ---------------------------------------------------------------------------
$Colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Info    = 'Cyan'
    Header  = 'White'
    Dim     = 'DarkGray'
}

# ---------------------------------------------------------------------------
# Logging helpers
# ---------------------------------------------------------------------------
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info','Success','Warning','Error','Header','Dim')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'Success' { '[+]' }
        'Warning' { '[!]' }
        'Error'   { '[x]' }
        'Header'  { '---' }
        'Dim'     { '   ' }
        default   { '[i]' }
    }

    $color = $Colors[$Level]
    Write-Host "$prefix $Message" -ForegroundColor $color

    # Append to log file (best-effort)
    $logDir = Split-Path $Global:OVAConfig.LogFile
    if (Test-Path $logDir) {
        try {
            "$timestamp $prefix $Message" | Out-File -FilePath $Global:OVAConfig.LogFile -Append -Encoding utf8
        } catch { }
    }
}

function Write-Header {
    param([string]$Title)
    $line = '-' * ($Title.Length + 4)
    Write-Host ''
    Write-Host $line -ForegroundColor $Colors.Header
    Write-Host "  $Title" -ForegroundColor $Colors.Header
    Write-Host $line -ForegroundColor $Colors.Header
}

function Exit-WithError {
    param([string]$Message)
    Write-Log $Message -Level Error
    exit 1
}

# ---------------------------------------------------------------------------
# Privilege check
# ---------------------------------------------------------------------------
function Test-Administrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-Administrator {
    if (-not (Test-Administrator)) {
        Exit-WithError 'This script must be run as Administrator. Right-click PowerShell -> Run as Administrator.'
    }
    Write-Log 'Running with Administrator privileges.' -Level Success
}

# ---------------------------------------------------------------------------
# Windows version check
# ---------------------------------------------------------------------------
function Assert-WindowsVersion {
    $os = [System.Environment]::OSVersion.Version
    $build = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuild

    if ($os.Major -lt 10) {
        Exit-WithError "Windows 10 or later is required. Detected: Windows $($os.Major).$($os.Minor)"
    }

    Write-Log "Windows $($os.Major) (Build $build) detected." -Level Success

    # WSL2 / Hyper-V is needed for Docker Desktop
    if ([int]$build -lt 19041) {
        Write-Log 'Build 19041 (20H1) or later is required for WSL2 back-end.' -Level Warning
        Write-Log 'Update Windows before continuing.' -Level Warning
    }
}

# ---------------------------------------------------------------------------
# Virtualisation check
# ---------------------------------------------------------------------------
function Test-VirtualizationEnabled {
    try {
        $cpu = Get-WmiObject -Class Win32_Processor -ErrorAction Stop
        $virt = $cpu | Select-Object -ExpandProperty VirtualizationFirmwareEnabled -ErrorAction SilentlyContinue
        return ($virt -eq $true)
    } catch {
        return $null  # Unable to determine
    }
}

function Assert-Virtualization {
    $result = Test-VirtualizationEnabled
    if ($result -eq $false) {
        Write-Log 'Hardware virtualisation is DISABLED in BIOS/UEFI.' -Level Warning
        Write-Log 'Docker Desktop requires Intel VT-x / AMD-V. Enable it in your BIOS settings.' -Level Warning
        Write-Log 'Continuing -- Docker may fail to start if virtualisation is off.' -Level Warning
    } elseif ($result -eq $true) {
        Write-Log 'Hardware virtualisation is enabled.' -Level Success
    } else {
        Write-Log 'Could not verify virtualisation status. Verify manually in BIOS if Docker fails.' -Level Warning
    }
}

# ---------------------------------------------------------------------------
# Resource checks
# ---------------------------------------------------------------------------
function Assert-SystemResources {
    # RAM
    $ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $ramGB    = [math]::Round($ramBytes / 1GB, 1)
    if ($ramGB -lt $Global:OVAConfig.MinRamGB) {
        Write-Log "RAM: ${ramGB} GB -- below recommended ${($Global:OVAConfig.MinRamGB)} GB. Performance may degrade." -Level Warning
    } else {
        Write-Log "RAM: ${ramGB} GB -- OK." -Level Success
    }

    # Disk (C: drive or the drive containing the deploy dir)
    $drive = Split-Path -Qualifier $Global:OVAConfig.DeployDir
    $disk  = Get-PSDrive -Name ($drive.TrimEnd(':')) -ErrorAction SilentlyContinue
    if ($disk) {
        $freeGB = [math]::Round($disk.Free / 1GB, 1)
        if ($freeGB -lt $Global:OVAConfig.MinDiskGB) {
            Write-Log "Free disk on ${drive}: ${freeGB} GB -- below recommended $($Global:OVAConfig.MinDiskGB) GB." -Level Warning
        } else {
            Write-Log "Free disk on ${drive}: ${freeGB} GB -- OK." -Level Success
        }
    }
}

# ---------------------------------------------------------------------------
# Docker helpers
# ---------------------------------------------------------------------------
function Test-DockerInstalled {
    return ($null -ne (Get-Command docker -ErrorAction SilentlyContinue))
}

function Test-DockerComposeAvailable {
    try {
        $null = docker compose version 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-DockerRunning {
    try {
        $null = docker info 2>&1
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Assert-DockerReady {
    if (-not (Test-DockerInstalled)) {
        Exit-WithError 'Docker is not installed. Run Install-Greenbone.ps1 first.'
    }
    if (-not (Test-DockerComposeAvailable)) {
        Exit-WithError 'Docker Compose v2 not available. Ensure Docker Desktop is up to date.'
    }
    if (-not (Test-DockerRunning)) {
        Exit-WithError 'Docker daemon is not running. Start Docker Desktop and try again.'
    }
    Write-Log 'Docker is installed and running.' -Level Success
}

function Assert-ComposeFile {
    if (-not (Test-Path $Global:OVAConfig.ComposeFile)) {
        Exit-WithError "compose.yaml not found at '$($Global:OVAConfig.ComposeFile)'. Run Install-Greenbone.ps1 first."
    }
}

# Convenience wrapper matching the Linux 'dc' alias
function Invoke-DockerCompose {
    param([string[]]$Arguments)
    & docker compose -f $Global:OVAConfig.ComposeFile @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "docker compose exited with code $LASTEXITCODE"
    }
}

# ---------------------------------------------------------------------------
# Wait for Docker Desktop to become responsive
# ---------------------------------------------------------------------------
function Wait-DockerReady {
    param([int]$TimeoutSeconds = $Global:OVAConfig.DockerStartupTimeoutSec)

    Write-Log "Waiting for Docker Desktop to start (timeout: ${TimeoutSeconds}s)..." -Level Info
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    while ((Get-Date) -lt $deadline) {
        if (Test-DockerRunning) {
            Write-Log 'Docker Desktop is ready.' -Level Success
            return
        }
        Start-Sleep -Seconds 5
        Write-Host '.' -NoNewline -ForegroundColor DarkGray
    }

    Write-Host ''
    Exit-WithError "Docker Desktop did not start within ${TimeoutSeconds} seconds. Start it manually and retry."
}

# Export all public functions (config is $Global:OVAConfig -- no export needed)
Export-ModuleMember -Function *
