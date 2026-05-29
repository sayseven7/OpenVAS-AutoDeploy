<#
.SYNOPSIS
    Streams live container logs for Greenbone Community Edition on Windows.

.PARAMETER Service
    Optional. Name of a specific service to follow (e.g., 'gvmd', 'gsad').
    Defaults to all services.

.PARAMETER DeployDir
    Path to the directory containing compose.yaml.

.PARAMETER Tail
    Number of recent lines to show before following. Default: 50

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
#>

[CmdletBinding()]
param(
    [string] $Service   = '',
    [string] $DeployDir = '',
    [int]    $Tail      = 50
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules\Common.psm1') -Force

if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
}

Assert-DockerReady
Assert-ComposeFile

if ($Service -ne '') {
    Write-Log "Following logs for service: $Service  (Ctrl+C to stop)" -Level Info
    & docker compose -f $Global:OVAConfig.ComposeFile logs -f --tail=$Tail $Service
} else {
    Write-Log "Following all container logs  (Ctrl+C to stop)" -Level Info
    & docker compose -f $Global:OVAConfig.ComposeFile logs -f --tail=$Tail
}
