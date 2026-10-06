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
    Write-tauredLog "Self test: interface built at $($result.Window.Width)x$($result.Window.Height)."
    $result.Window.Close()
    Write-tauredLog "Self test: passed."
    return 0
}

$result.Window.ShowDialog() | Out-Null
Write-tauredLog "taured closed."
return 0