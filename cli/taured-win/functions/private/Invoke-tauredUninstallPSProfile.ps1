function Invoke-tauredUninstallPSProfile {
    <#
    .SYNOPSIS
        Restores the PowerShell 7 profile that was replaced during setup

    .DESCRIPTION
        The profile path has to come from pwsh itself. $PROFILE inside this job is the worker's
        own Windows PowerShell profile, which is not the file the install wrote.
    #>

    $pwshPath = Get-tauredPowerShell7Path
    if (-not $pwshPath) {
        throw "PowerShell 7 is not installed, so there is no profile to remove."
    }

    $profilePath = (& $pwshPath -NoProfile -NonInteractive -Command '$PROFILE' | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($profilePath)) {
        throw "Could not determine the PowerShell 7 profile path."
    }
    $profilePath = $profilePath.Trim()
    $backupPath = "$profilePath.bak"

    if (Test-Path $backupPath) {
        Move-Item -Path $backupPath -Destination $profilePath -Force
        Write-tauredLog -Component "Feature" -Message "Restored the profile that was in place before: $profilePath"
        return
    }

    if (Test-Path $profilePath) {
        Remove-Item -Path $profilePath -Force
        Write-tauredLog -Component "Feature" -Message "Removed the installed PowerShell profile: $profilePath"
        return
    }

    Write-tauredLog -Level "WARN" -Component "Feature" -Message "No PowerShell 7 profile found at $profilePath, nothing to remove."
}
