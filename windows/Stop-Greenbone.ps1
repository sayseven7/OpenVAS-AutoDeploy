<#
.SYNOPSIS
    Stops Greenbone Community Edition containers on Windows.

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

Write-Header 'Stopping Greenbone Community Edition'
Assert-DockerReady
Assert-ComposeFile

Write-Log 'Stopping all containers...' -Level Info
Invoke-DockerCompose @('down')

Write-Log 'Greenbone Community Edition stopped.' -Level Success
