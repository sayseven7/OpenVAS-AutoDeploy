<#
.SYNOPSIS
    Updates the GVM admin account password for Greenbone Community Edition.

.PARAMETER Password
    Mandatory. The new password for the admin account.

.PARAMETER DeployDir
    Path to the directory containing compose.yaml.

.EXAMPLE
    .\Set-AdminPassword.ps1 -Password 'MyStr0ngP@ss!'

.NOTES
    Author  : Lucas Morais (SaySeven / @sayseven7)
    Project : OpenVAS-AutoDeploy
    License : MIT
    Requires: gvmd container must be running and initialised.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Password,

    [string] $DeployDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'modules\Common.psm1') -Force

if ($DeployDir -ne '') {
    $Global:OVAConfig.DeployDir   = $DeployDir
    $Global:OVAConfig.ComposeFile = Join-Path $DeployDir 'compose.yaml'
}

Write-Header 'GVM Admin Password Update'
Assert-DockerReady
Assert-ComposeFile

Write-Log 'Updating admin password...' -Level Info

& docker compose -f $Global:OVAConfig.ComposeFile exec -u gvmd gvmd `
    gvmd --user=admin --new-password=$Password

if ($LASTEXITCODE -eq 0) {
    Write-Log 'Password updated successfully. New credentials: admin / <your new password>' -Level Success
} else {
    Exit-WithError "Password update failed (exit code $LASTEXITCODE). Ensure the gvmd container is fully started."
}
