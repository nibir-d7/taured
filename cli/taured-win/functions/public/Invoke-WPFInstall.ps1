function Invoke-WPFInstall {
    <#
    .SYNOPSIS
        Installs the selected programs using winget, if one or more of the selected programs are already installed on the system, winget will try and perform an upgrade if there's a newer version to install.
    #>
    param(
        [Parameter(Mandatory = $false)]
        [PSObject[]]$PackagesToInstall = $($sync.selectedApps | Foreach-Object { $sync.configs.applicationsHashtable.$_ })
    )

    if ($PackagesToInstall.Count -eq 0) {
        $WarningMsg = "Please select the program(s) to install or upgrade."
        Show-tauredMessage -Message $WarningMsg -Title "taured" -Button "OK" -Icon "Warning"
        return
    }

    $ManagerPreference = $sync.preferences.packagemanager
    Write-tauredLog -Component "Install" -Message "Install requested for $(@($PackagesToInstall).Count) selected package(s) using preference: $ManagerPreference"
    $packageSummary = Get-tauredPackageLogSummary -Packages $PackagesToInstall -Preference $ManagerPreference
    Write-tauredLog -Component "Install" -Message "Install selected package(s): $($packageSummary -join '; ')"

    Start-tauredJob -Name "Install" -Description "Installing apps" -DisableAppList -Parameters @{
        PackagesToInstall = $PackagesToInstall
        ManagerPreference = $ManagerPreference
    } -ScriptBlock {
        param($PackagesToInstall, $ManagerPreference)

        $packagesSorted = Get-tauredSelectedPackages -PackageList $PackagesToInstall -Preference $ManagerPreference
        $packagesWinget = $packagesSorted['Winget']
        $packagesChoco = $packagesSorted['Choco']
        $totalPackages = @($packagesWinget).Count + @($packagesChoco).Count
        $completedPackages = 0
        Write-tauredLog -Component "Install" -Message "Install package manager split: winget=$(@($packagesWinget).Count), choco=$(@($packagesChoco).Count)"

        $results = @()

        if ($packagesWinget.Count -gt 0 -and $packagesWinget -ne "0") {
            Install-tauredWinget
            foreach ($program in $packagesWinget) {
                $position = $completedPackages + 1
                Step-tauredJob -Status "Installing $program ($position/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))

                $results += Measure-tauredStep -Scope "Install" -Name "winget $program" -ScriptBlock {
                    Install-tauredProgramWinget -Action Install -Programs @($program)
                }
                $completedPackages++
                Step-tauredJob -Status "Installed $program ($completedPackages/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))
            }
        }

        if ($packagesChoco.Count -gt 0) {
            $position = $completedPackages + 1
            Step-tauredJob -Status "Installing Chocolatey packages ($position/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))

            Install-tauredChoco
            $chocoBase = [int](($completedPackages / $totalPackages) * 100)
            $chocoSpan = [int]((@($packagesChoco).Count / $totalPackages) * 100)
            $results += Measure-tauredStep -Scope "Install" -Name "choco $($packagesChoco -join ', ')" -ScriptBlock {
                Install-tauredProgramChoco -Action Install -Programs $packagesChoco -ProgressBase $chocoBase -ProgressSpan $chocoSpan
            }
            $completedPackages += @($packagesChoco).Count
            Step-tauredJob -Status "Installed Chocolatey packages ($completedPackages/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))
        }

        Complete-tauredPackageRun -Action "Install" -Results $results
    }
}
