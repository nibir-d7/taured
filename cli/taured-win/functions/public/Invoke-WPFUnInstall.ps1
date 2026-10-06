function Invoke-WPFUnInstall {
    param(
        [Parameter(Mandatory=$false)]
        [PSObject[]]$PackagesToUninstall = $($sync.selectedApps | Foreach-Object { $sync.configs.applicationsHashtable.$_ })
    )
    <#

    .SYNOPSIS
        Uninstalls the selected programs
    #>

    if ($PackagesToUninstall.Count -eq 0) {
        $WarningMsg = "Please select the program(s) to uninstall"
        Show-tauredMessage -Message $WarningMsg -Title "taured" -Button "OK" -Icon "Warning"
        return
    }

    $ButtonType = "YesNo"
    $MessageboxTitle = "Are you sure?"
    $Messageboxbody = ("This will uninstall the following applications: `n $($PackagesToUninstall | Select-Object Name, Description| Out-String)")
    $MessageIcon = "Information"

    $confirm = Show-tauredMessage -Message $Messageboxbody -Title $MessageboxTitle -Button $ButtonType -Icon $MessageIcon

    if ($confirm -ne "Yes") { return }

    $ManagerPreference = $sync.preferences.packagemanager
    Write-tauredLog -Component "Uninstall" -Message "Uninstall requested for $(@($PackagesToUninstall).Count) selected package(s) using preference: $ManagerPreference"
    $packageSummary = Get-tauredPackageLogSummary -Packages $PackagesToUninstall -Preference $ManagerPreference
    Write-tauredLog -Component "Uninstall" -Message "Uninstall selected package(s): $($packageSummary -join '; ')"

    Start-tauredJob -Name "Uninstall" -Description "Uninstalling apps" -DisableAppList -Parameters @{
        PackagesToUninstall = $PackagesToUninstall
        ManagerPreference = $ManagerPreference
    } -ScriptBlock {
        param($PackagesToUninstall, $ManagerPreference)

        $packagesSorted = Get-tauredSelectedPackages -PackageList $PackagesToUninstall -Preference $ManagerPreference
        $packagesWinget = $packagesSorted['Winget']
        $packagesChoco = $packagesSorted['Choco']
        $totalPackages = @($packagesWinget).Count + @($packagesChoco).Count
        $completedPackages = 0
        Write-tauredLog -Component "Uninstall" -Message "Uninstall package manager split: winget=$(@($packagesWinget).Count), choco=$(@($packagesChoco).Count)"

        if ($packagesWinget -contains "Microsoft.Edge") {
            New-Item -Path "$Env:SystemRoot\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\MicrosoftEdge.exe" -Force | Out-Null
        }

        $results = @()

        if ($packagesWinget.Count -gt 0) {
            foreach ($program in $packagesWinget) {
                $position = $completedPackages + 1
                Step-tauredJob -Status "Uninstalling $program ($position/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))

                $results += Measure-tauredStep -Scope "Uninstall" -Name "winget $program" -ScriptBlock {
                    Install-tauredProgramWinget -Action Uninstall -Programs @($program)
                }
                $completedPackages++
                Step-tauredJob -Status "Uninstalled $program ($completedPackages/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))
            }
        }

        if ($packagesChoco.Count -gt 0) {
            $position = $completedPackages + 1
            Step-tauredJob -Status "Uninstalling Chocolatey packages ($position/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))

            $chocoBase = [int](($completedPackages / $totalPackages) * 100)
            $chocoSpan = [int]((@($packagesChoco).Count / $totalPackages) * 100)
            $results += Measure-tauredStep -Scope "Uninstall" -Name "choco $($packagesChoco -join ', ')" -ScriptBlock {
                Install-tauredProgramChoco -Action Uninstall -Programs $packagesChoco -ProgressBase $chocoBase -ProgressSpan $chocoSpan
            }
            $completedPackages += @($packagesChoco).Count
            Step-tauredJob -Status "Uninstalled Chocolatey packages ($completedPackages/$totalPackages)" -Percent ([int](($completedPackages / $totalPackages) * 100))
        }

        Complete-tauredPackageRun -Action "Uninstall" -Results $results
    }
}
