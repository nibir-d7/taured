function Invoke-WPFAppxInstall {
    if ($null -eq $sync.selectedAppx -or $sync.selectedAppx.Count -eq 0) {
        Show-tauredMessage -Message "No AppX Package selected" -Title "Error" -Button "OK" -Icon "Error"
        return
    }

    Start-tauredJob -Name "AppX install" -Description "Installing AppX packages" -Parameters @{
        Selected = @($sync.selectedAppx)
        Apps = $sync.configs.appxHashtable
    } -ScriptBlock {
        param($Selected, $Apps)

        $totalPackages = @($Selected).Count
        $results = @()
        Write-tauredLog -Component "AppX" -Message "Starting AppX install for $totalPackages selected package(s)."

        for ($index = 0; $index -lt $totalPackages; $index++) {
            $app = $Apps[$Selected[$index]]
            $position = $index + 1

            Step-tauredJob -Status "Installing $($app.Content) ($position/$totalPackages)" -Percent ([int](($index / $totalPackages) * 100))
            Write-Host "Installing $($app.Content)"
            $appResults = @(Install-tauredAPPX -Name $app.PackageId -StoreId $app.StoreId)
            $results += $appResults
            $status = if (@($appResults | Where-Object Outcome -EQ "Failed").Count -gt 0) {
                "Failed"
            } elseif (@($appResults | Where-Object Outcome -EQ "Skipped").Count -gt 0) {
                "Skipped"
            } else {
                "Installed"
            }
            Step-tauredJob -Status "$status $($app.Content) ($position/$totalPackages)" -Percent ([int](($position / $totalPackages) * 100))
        }

        Complete-tauredPackageRun -Action "Install" -Results $results
    }
}
