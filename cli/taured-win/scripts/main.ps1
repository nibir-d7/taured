$ErrorActionPreference = "Continue"

$tauredVersion = "#{replaceme}"
$tauredDir = Join-Path $env:LOCALAPPDATA "taured"
$tauredLogDir = Join-Path $tauredDir "logs"

foreach ($folder in @($tauredDir, $tauredLogDir)) {
    if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
}

$tauredLogPath = Join-Path $tauredLogDir ("taured_{0}_{1}.log" -f (Get-Date -Format "yyyy-MM-dd_HH-mm-ss"), $PID)

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

function Write-tauredLog {
    param([string]$Message, [string]$Level = "INFO")

    $line = "{0} [{1}] {2}" -f (Get-Date -Format "HH:mm:ss"), $Level, $Message
    try { Add-Content -Path $tauredLogPath -Value $line } catch { }
    Write-Host $Message
}

$tauredPresets = @{
    Standard = @("WPFTweaksTelemetry", "WPFTweaksConsumerFeatures", "WPFTweaksDarkMode", "WPFTweaksDeleteTempFiles", "WPFTweaksRestorePoint")
    Minimal = @("WPFTweaksTelemetry", "WPFTweaksConsumerFeatures")
    Advanced = @("WPFTweaksTelemetry", "WPFTweaksConsumerFeatures", "WPFTweaksServices", "WPFTweaksDarkMode", "WPFTweaksDisableStoreSearch", "WPFTweaksDeleteTempFiles", "WPFTweaksRestorePoint", "WPFTweaksDisableBGapps")
}

Write-tauredLog "taured $($sync.version) starting."

if ($Preset -and $tauredPresets.ContainsKey($Preset)) {
    Write-tauredLog "Applying the $Preset preset without the interface."
    Write-tauredLog (New-tauredRestorePoint)
    foreach ($line in (Invoke-tauredTweaks -Configs $sync.configs -Ids $tauredPresets[$Preset])) {
        Write-tauredLog $line
    }
    Write-tauredLog "Done. Restart recommended."
    return 0
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne "STA") {
    Write-tauredLog "The interface needs a single-threaded apartment host." "ERROR"
    return 1
}

$result = New-tauredInterface -Configs $sync.configs -Palette (Get-tauredPalette) -Version $sync.version

if ($SelfTest) {
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Stop"
    try {
        Write-tauredLog "Self test: interface built at $($result.Window.Width)x$($result.Window.Height)."
        foreach ($tab in @("install", "tweaks", "updates", "config")) {
            Set-tauredTab -Ui $result.Ui -Tab $tab
            Show-tauredTab -Ui $result.Ui -Window $result.Window -Sidebar $result.Ui.Rows["sidebar"] -Content $result.Ui.Rows["content"]
            if ($tab -eq "install" -and $result.Ui.Rows["list"].Items.Count -gt 0) {
                Write-tauredLog ("Self test: install list state attached = $($null -ne $result.Ui.Rows['list'].Tag), details ready = $($null -ne $result.Ui.Rows['detail'])")
                $result.Ui.Rows["list"].SelectedIndex = 0
                $appId = $result.Ui.Rows["list"].SelectedItem.Id
                $appToggle = $result.Ui.Rows["detail"].Child.Children[6]
                $appToggle.IsChecked = $true
                $appToggle.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                if (-not $result.Ui.SelectedApps[$appId]) { throw "App selection did not persist." }
            }
            if ($tab -eq "tweaks" -and $result.Ui.Rows["tweaksList"].Items.Count -gt 0) {
                $result.Ui.Rows["tweaksList"].SelectedIndex = 0
                $tweakId = $result.Ui.Rows["tweaksList"].SelectedItem.Id
                $tweakToggle = $result.Ui.Rows["detail"].Child.Children[6]
                $tweakToggle.IsChecked = $true
                $tweakToggle.RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
                if (-not $result.Ui.SelectedTweaks[$tweakId]) { throw "Tweak selection did not persist." }
            }
            Write-tauredLog "Self test: $tab view and selection built."
        }
        $result.Ui.Rows["tab_updates"].RaiseEvent([System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))
        if ($result.Ui.Tab -ne "updates") { throw "Tab navigation did not update the active tab." }
        Update-tauredDetail -Ui $result.Ui -Entry ([pscustomobject]@{
                Id = "self-test"
                Name = "Detail panel"
                Category = "Self test"
                Description = "Validates selectable-item details."
                Source = "self test"
                Link = $null
            })
        Write-tauredLog "Self test: detail panel built."
        $result.Window.Close()
        Write-tauredLog "Self test: passed."
        return 0
    }
    catch {
        Write-tauredLog ("Self test failed: " + ($_ | Out-String -Width 240).Trim()) "ERROR"
        $result.Window.Close()
        return 1
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
}

$result.Window.ShowDialog() | Out-Null
Write-tauredLog "taured closed."
return 0
