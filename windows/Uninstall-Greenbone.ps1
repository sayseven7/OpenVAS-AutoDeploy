#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Completely removes Greenbone Community Edition from Windows.

.DESCRIPTION
    Stops all containers, removes Docker volumes (all scan data),
    and optionally deletes the deployment directory.
    Docker Desktop itself is NOT uninstalled.

.PARAMETER DeployDir
    Path to the directory containing compose.yaml.
    Default: %USERPROFILE%\greenbone-community-container

.PARAMETER Force
    Skip confirmation prompts.

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
    WARNING : This permanently deletes all Greenbone data including scan results.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $DeployDir = '',
    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules\Common.psm1') -Force

if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
}

Write-Header 'OpenVAS AutoDeploy -- Uninstall'
Write-Log 'WARNING: This will permanently delete all Greenbone containers, volumes, and scan data.' -Level Warning
Write-Host ''

if (-not $Force) {
    $confirm = Read-Host 'Type YES to confirm complete removal'
    if ($confirm -ne 'YES') {
        Write-Log 'Aborted.' -Level Info
        exit 0
    }
}

Assert-DockerReady

# Stop containers and remove volumes
if (Test-Path $Global:OVAConfig.ComposeFile) {
    Write-Log 'Stopping containers and removing volumes...' -Level Info
    try {
        & docker compose -f $Global:OVAConfig.ComposeFile down -v --remove-orphans
    } catch {
        Write-Log "Container teardown warning: $_" -Level Warning
    }
} else {
    Write-Log "compose.yaml not found at '$($Global:OVAConfig.ComposeFile)'. Skipping container teardown." -Level Warning
}

# Remove deployment directory
if (Test-Path $Global:OVAConfig.DeployDir) {
    $removeDir = $Force
    if (-not $Force) {
        $answer = Read-Host "Delete deployment directory '$($Global:OVAConfig.DeployDir)'? [y/N]"
        $removeDir = ($answer -eq 'y' -or $answer -eq 'Y')
    }

    if ($removeDir) {
        Remove-Item -Path $Global:OVAConfig.DeployDir -Recurse -Force
        Write-Log "Removed: $($Global:OVAConfig.DeployDir)" -Level Success
    } else {
        Write-Log "Kept: $($Global:OVAConfig.DeployDir)" -Level Info
    }
}

Write-Log 'Greenbone Community Edition has been removed.' -Level Success
Write-Log 'Docker Desktop was NOT uninstalled. Remove it via Windows Settings > Apps if needed.' -Level Info
