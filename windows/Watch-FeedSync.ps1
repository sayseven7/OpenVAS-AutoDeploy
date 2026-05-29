<#
.SYNOPSIS
    Monitors Greenbone Community Edition feed synchronisation progress on Windows.

.DESCRIPTION
    Streams or summarises log output from the gvmd and ospd-openvas containers,
    filtering for feed-sync related messages (NVT, CVE, CERT, SCAP, VT).

.PARAMETER Mode
    Follow   : Stream sync-related log lines in real time (default)
    Summary  : One-shot container status + recent sync messages
    All      : Stream ALL container log lines (no filter)

.PARAMETER DeployDir
    Path to the directory containing compose.yaml.
    Default: %USERPROFILE%\greenbone-community-container

.PARAMETER Tail
    Number of recent log lines to scan in Summary mode. Default: 500

.EXAMPLE
    # Real-time sync monitoring
    .\Watch-FeedSync.ps1

.EXAMPLE
    # One-shot summary
    .\Watch-FeedSync.ps1 -Mode Summary

.EXAMPLE
    # All logs from a custom directory
    .\Watch-FeedSync.ps1 -Mode All -DeployDir 'D:\greenbone'

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
#>

[CmdletBinding()]
param(
    [ValidateSet('Follow', 'Summary', 'All')]
    [string] $Mode      = 'Follow',
    [string] $DeployDir = '',
    [int]    $Tail      = 500
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------
$ModulePath = Join-Path $PSScriptRoot 'modules\Common.psm1'
if (-not (Test-Path $ModulePath)) {
    Write-Error "Cannot find Common.psm1 at '$ModulePath'."
    exit 1
}
Import-Module $ModulePath -Force

if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
    $Global:OVAConfig.LogFile     = Join-Path $DeployDir 'openvas-autodeploy.log'
}

Assert-DockerReady
Assert-ComposeFile

# ---------------------------------------------------------------------------
# Sync-related keyword pattern
# ---------------------------------------------------------------------------
$SyncKeywords = @(
    'sync', 'updating', 'finished', 'loaded',
    'vt', 'nvt', 'cert', 'cve', 'cpe', 'scap', 'feed',
    'error', 'warn', 'starting', 'completed'
)
$SyncPattern = ($SyncKeywords -join '|')

# ---------------------------------------------------------------------------
# Colour-coded log line output
# ---------------------------------------------------------------------------
function Write-SyncLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return }

    $lower = $Line.ToLower()
    $color = switch -Regex ($lower) {
        'error|fail'               { 'Red'    }
        'warn'                     { 'Yellow' }
        'finished|loaded|complet'  { 'Green'  }
        'sync|updating'            { 'Cyan'   }
        default                    { 'Gray'   }
    }

    Write-Host $Line -ForegroundColor $color
}

# ---------------------------------------------------------------------------
# Modes
# ---------------------------------------------------------------------------
function Invoke-FollowMode {
    Write-Header 'Feed Synchronisation -- Live Monitor'
    Write-Log "Compose: $($Global:OVAConfig.ComposeFile)" -Level Info
    Write-Log 'Press Ctrl+C to stop.' -Level Dim
    Write-Host ''

    & docker compose -f $Global:OVAConfig.ComposeFile logs -f gvmd ospd-openvas 2>&1 |
        ForEach-Object {
            if ($_ -match $SyncPattern) {
                Write-SyncLine $_
            }
        }
}

function Invoke-SummaryMode {
    Write-Header 'Feed Synchronisation -- Summary'
    Write-Log "Compose: $($Global:OVAConfig.ComposeFile)" -Level Info
    Write-Host ''

    # Container status table
    Write-Log 'Container Status:' -Level Info
    & docker compose -f $Global:OVAConfig.ComposeFile ps
    Write-Host ''

    # Recent sync messages
    Write-Log "Scanning last $Tail log lines for sync events..." -Level Info
    Write-Host ''

    $lines = & docker compose -f $Global:OVAConfig.ComposeFile logs --tail=$Tail gvmd ospd-openvas 2>&1 |
        Where-Object { $_ -match $SyncPattern }

    if ($lines) {
        $lines | ForEach-Object { Write-SyncLine $_ }
    } else {
        Write-Log 'No sync-related messages found in recent logs.' -Level Warning
    }

    Write-Host ''
    Write-Host '  Interpretation Guide:' -ForegroundColor White
    Write-Host "    [Green]  'Finished loading VTs'     -> scanner plugins fully loaded" -ForegroundColor DarkGray
    Write-Host "    [Cyan]   'Updating ... nvdcve'       -> CVE feed sync in progress" -ForegroundColor DarkGray
    Write-Host "    [Cyan]   'Starting sync'             -> feed update just kicked off" -ForegroundColor DarkGray
    Write-Host "    Web UI banner 'Feed syncing'         -> sync still running (normal)" -ForegroundColor DarkGray
    Write-Host ''
}

function Invoke-AllMode {
    Write-Header 'All Container Logs -- Live'
    Write-Log "Compose: $($Global:OVAConfig.ComposeFile)" -Level Info
    Write-Log 'Press Ctrl+C to stop.' -Level Dim
    Write-Host ''

    & docker compose -f $Global:OVAConfig.ComposeFile logs -f 2>&1 |
        ForEach-Object { Write-Host $_ -ForegroundColor Gray }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
switch ($Mode) {
    'Follow'  { Invoke-FollowMode  }
    'Summary' { Invoke-SummaryMode }
    'All'     { Invoke-AllMode     }
}
