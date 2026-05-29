<#
.SYNOPSIS
    Displays Greenbone Community Edition container health status on Windows.

.PARAMETER DeployDir
    Path to the directory containing compose.yaml.
    Default: %USERPROFILE%\greenbone-community-container

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
#>

[CmdletBinding()]
param(
    [string] $DeployDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules\Common.psm1') -Force

if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
}

Write-Header 'Greenbone Community Edition -- Status'
Assert-DockerReady
Assert-ComposeFile

& docker compose -f $Global:OVAConfig.ComposeFile ps

Write-Host ''
Write-Log 'Web interface: https://127.0.0.1  |  https://127.0.0.1:9392' -Level Info
Write-Log 'Default credentials: admin / admin' -Level Info
Write-Log 'Run Watch-FeedSync.ps1 to monitor feed synchronisation.' -Level Dim
