function Invoke-WPFFeatureInstall {
    <#

    .SYNOPSIS
        Installs selected Windows Features

    #>

    if ($null -eq $sync.selectedFeatures -or $sync.selectedFeatures.Count -eq 0) {
        Show-tauredMessage -Message "No Windows Feature selected" -Title "taured" -Button "OK" -Icon "Warning"
        return
    }

    Start-tauredJob -Name "Features" -Description "Installing Windows features" -Parameters @{
        Features = @($sync.selectedFeatures)
    } -ScriptBlock {
        param($Features)

        $total = @($Features).Count
        $completed = 0

        foreach ($feature in $Features) {
            $completed++
            Step-tauredJob -Status "Installing $feature ($completed/$total)" -Percent ([int]((($completed - 1) / $total) * 100))
            Measure-tauredStep -Scope "Features" -Name $feature -ScriptBlock {
                Invoke-tauredFeatureInstall $feature
            }
            Step-tauredJob -Status "Installed $feature ($completed/$total)" -Percent ([int](($completed / $total) * 100))
        }

        Write-Host "A reboot may be required."
    }
}
