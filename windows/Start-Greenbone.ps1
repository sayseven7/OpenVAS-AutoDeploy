<#
.SYNOPSIS
    Starts Greenbone Community Edition containers on Windows.

.PARAMETER DeployDir
    Path to the directory containing compose.yaml.
    Default: %USERPROFILE%\greenbone-community-container

.PARAMETER Pull
    Pull latest images before starting.

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
#>

[CmdletBinding()]
param(
    [string] $DeployDir = '',
    [switch] $Pull
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules\Common.psm1') -Force

if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
}

Write-Header 'Starting Greenbone Community Edition'
Assert-DockerReady
Assert-ComposeFile

if ($Pull) {
    Write-Log 'Pulling latest container images...' -Level Info
    Invoke-DockerCompose @('pull')
}

Write-Log 'Starting containers...' -Level Info
Invoke-DockerCompose @('up', '-d')

Write-Log 'Greenbone Community Edition is starting.' -Level Success
Write-Log 'Run Get-Status.ps1 to check container health.' -Level Info
Write-Log 'Web UI: https://127.0.0.1  (may take 1-2 minutes to become available)' -Level Info
