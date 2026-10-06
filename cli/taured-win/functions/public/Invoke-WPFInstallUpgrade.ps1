function Invoke-WPFInstallUpgrade {
    <#

    .SYNOPSIS
        Upgrades every package that has an update available

    .DESCRIPTION
        Runs on the worker like any other package work, so the progress bar, the taskbar item
        and the log report it the same way an install does.

    #>

    # The radio button belongs to the interface thread; this body runs on a worker. The
    # preference it maintains carries the same answer and is what every other workflow reads.
    if ($sync.preferences.packagemanager -eq "Choco") {
        Step-tauredJob -Status "Preparing Chocolatey" -State "Indeterminate"
        Install-tauredChoco

        Write-tauredLog -Component "Install" -Message "Upgrading all Chocolatey packages."
        Step-tauredJob -Status "Upgrading all Chocolatey packages" -State "Indeterminate"

        # "all" is choco's own name for every installed package, so this stays one call
        $result = Measure-tauredStep -Scope "Install" -Name "choco upgrade all" -ScriptBlock {
            Install-tauredProgramChoco -Action Upgrade -Programs @("all")
        }
        Complete-tauredPackageRun -Action "Upgrade" -Results @($result)
        return
    }

    Step-tauredJob -Status "Preparing WinGet" -State "Indeterminate"
    Install-tauredWinget

    Write-tauredLog -Component "Install" -Message "Upgrading all WinGet packages."
    Step-tauredJob -Status "Upgrading all WinGet packages" -State "Indeterminate"

    # Let WinGet resolve every package against its recorded source. Parsing its localized,
    # width-truncated table loses identifiers and source information.
    $result = Measure-tauredStep -Scope "Install" -Name "winget upgrade --all" -ScriptBlock {
        Install-tauredProgramWinget -Action Upgrade -Programs @("all")
    }
    Complete-tauredPackageRun -Action "Upgrade" -Results @($result)
}
