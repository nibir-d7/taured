<#
.NOTES
    taured          : https://taured.space
    GitHub          : https://github.com/nibir-d7/taured
    Based on WinUtil : Chris Titus Tech (https://github.com/ChrisTitusTech/winutil)
    Version         : 26.10.06
#>

param (
    [string]$Config,
    [ValidateSet("Standard", "Minimal", "Advanced", "")]
    [string]$Preset,
    [switch]$Offline,
    [switch]$SelfTest
)

$TAURED_RELEASE_URL = "https://github.com/nibir-d7/taured/releases/latest/download/taured.ps1"
$TAURED_RAW_URL = "https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-win/taured.ps1"

$tauredSourceText = if ($PSCommandPath) { Get-Content $PSCommandPath -Raw } else { $MyInvocation.MyCommand.Definition }
$tauredCompiledMarker = ('function New-taured' + 'Interface')
$tauredIsCompiled = $tauredSourceText -match $tauredCompiledMarker

if (-not $tauredIsCompiled) {
    Write-Host "taured: fetching the Windows toolbox..."
    $tauredPayload = $null
    foreach ($tauredCandidate in @($TAURED_RELEASE_URL, $TAURED_RAW_URL)) {
        try {
            $tauredPayload = (Invoke-WebRequest -UseBasicParsing -Uri $tauredCandidate -TimeoutSec 60).Content
            break
        } catch {
            Write-Host "taured: could not download from $tauredCandidate"
        }
    }
    if (-not $tauredPayload) {
        Write-Host "taured: download failed. Get the toolbox manually from https://github.com/nibir-d7/taured" -ForegroundColor Red
        $global:LASTEXITCODE = 1
        if (-not $env:TAURED_NO_PAUSE) { $null = Read-Host "Press Enter to close" }
        return 1
    }
    Write-Host "taured: downloaded. Launching..."
    $tauredBlock = [ScriptBlock]::Create($tauredPayload)
    $tauredArgs = @{}
    if ($Config) { $tauredArgs["Config"] = $Config }
    if ($Preset) { $tauredArgs["Preset"] = $Preset }
    if ($Offline) { $tauredArgs["Offline"] = $true }
    if ($SelfTest) { $tauredArgs["SelfTest"] = $true }
    & $tauredBlock @tauredArgs
    return
}

function Test-tauredOwnsFileProcess {
    <#
        .SYNOPSIS
            Whether the current process was launched with this script as its file target
    #>
    param(
        [string]$ScriptPath = $PSCommandPath,
        [string[]]$CommandLineArgs = [Environment]::GetCommandLineArgs()
    )

    if ([string]::IsNullOrWhiteSpace($ScriptPath)) { return $false }

    $hostOptionKinds = [ordered]@{
        Command           = "Command"
        EncodedCommand    = "Command"
        CommandWithArgs   = "Command"
        File              = "File"
        ConfigurationFile = "Value"
        ConfigurationName = "Value"
        CustomPipeName    = "Value"
        ExecutionPolicy   = "Value"
        InputFormat       = "Value"
        Interactive       = "Switch"
        Login             = "Switch"
        MTA               = "Switch"
        NoLogo            = "Switch"
        NonInteractive    = "Switch"
        NoProfile         = "Switch"
        NoProfileLoadTime = "Switch"
        OutputFormat      = "Value"
        PSConsoleFile     = "Value"
        SettingsFile      = "Value"
        SSHServerMode     = "Switch"
        STA               = "Switch"
        Version           = "Value"
        WindowStyle       = "Value"
        WorkingDirectory  = "Value"
        NoExit            = "NoExit"
    }
    $hostOptionAliases = @{
        c = "Command"; cwa = "Command"; e = "Command"; ec = "Command"; f = "File"
        noe = "NoExit"
        config = "Value"; ConfigName = "Value"; CustomPipe = "Value"; ep = "Value"; ex = "Value"
        i = "Switch"; Input = "Value"; In = "Value"; if = "Value"
        Output = "Value"; Out = "Value"; of = "Value"
        Settings = "Value"; Window = "Value"; w = "Value"; Working = "Value"; wd = "Value"
    }

    function Get-tauredHostOptionKind {
        param([string]$Argument)

        if ([string]::IsNullOrWhiteSpace($Argument) -or -not $Argument.StartsWith("-")) {
            return $null
        }

        $optionName = $Argument.TrimStart("-")
        if ($hostOptionAliases.ContainsKey($optionName)) {
            return $hostOptionAliases[$optionName]
        }

        # pwsh accepts any unambiguous prefix of a host option, such as -WorkingD.
        $matchingOptions = @($hostOptionKinds.Keys | Where-Object {
            $_.StartsWith($optionName, [StringComparison]::OrdinalIgnoreCase)
        })
        $matchingKinds = @($matchingOptions | ForEach-Object { $hostOptionKinds[$_] } | Select-Object -Unique)
        if ($matchingKinds.Count -eq 1) {
            return $matchingKinds[0]
        }

        return $null
    }

    :hostArguments for ($index = 1; $index -lt $CommandLineArgs.Count; $index++) {
        $optionKind = Get-tauredHostOptionKind -Argument $CommandLineArgs[$index]
        switch ($optionKind) {
            "Command" { return $false }
            "NoExit" { return $false }
            "Switch" { continue hostArguments }
            "File" {
                if ($index + 1 -ge $CommandLineArgs.Count) { return $false }
                $fileTarget = $CommandLineArgs[$index + 1]
                if ([string]::IsNullOrWhiteSpace($fileTarget) -or $fileTarget -eq "-") {
                    return $false
                }

                return [string]::Equals(
                    [IO.Path]::GetFullPath($fileTarget),
                    [IO.Path]::GetFullPath($ScriptPath),
                    [StringComparison]::OrdinalIgnoreCase
                )
            }
            "Value" {
                $index++
                continue hostArguments
            }
        }

        if ($CommandLineArgs[$index].StartsWith("-")) {
            continue
        }

        return [string]::Equals(
            [IO.Path]::GetFullPath($CommandLineArgs[$index]),
            [IO.Path]::GetFullPath($ScriptPath),
            [StringComparison]::OrdinalIgnoreCase
        )
    }

    return $false
}

# A headless script launched with powershell.exe/pwsh.exe -File owns its process and must set
# that process's exit code. An invoked or in-memory script must return without closing its caller.
$script:tauredIsFileProcess = Test-tauredOwnsFileProcess

$PARAM_OFFLINE = $false
if ($Offline) {
    $PARAM_OFFLINE = $true
}

if ($ExecutionContext.SessionState.LanguageMode -ne 'FullLanguage') {
    Write-Host "taured is unable to run on your system. PowerShell execution is restricted by security policies." -ForegroundColor Red
    $global:LASTEXITCODE = 1
    if ($env:taured_HEADLESS_CHILD -eq "1" -or $script:tauredIsFileProcess) { exit 1 }
    return 1
}

function New-tauredElevationCommand {
    <#
        .SYNOPSIS
            Encodes the relaunch target and bound parameters as data for an elevated child
    #>
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters = @{},
        [switch]$Headless
    )

    $launchData = @{
        ScriptPath = $ScriptPath
        Parameters = $Parameters
        Headless = [bool]$Headless
    }
    $serializedLaunch = [System.Management.Automation.PSSerializer]::Serialize($launchData)
    $launchPayload = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($serializedLaunch))

    # Only base64 is embedded in executable text. User-controlled values are deserialized and
    # splatted as parameter data in the child, so quotes in Config cannot become PowerShell code.
    $bootstrap = @"
`$launchXml = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('$launchPayload'))
`$launch = [System.Management.Automation.PSSerializer]::Deserialize(`$launchXml)
`$invokeParameters = `$launch.Parameters
if (`$launch.Headless) { `$env:taured_HEADLESS_CHILD = '1' }
if (`$launch.ScriptPath) {
    & `$launch.ScriptPath @invokeParameters
} else {
    `$tauredPayload = `$null
    foreach (`$tauredCandidate in @('https://github.com/nibir-d7/taured/releases/latest/download/taured.ps1', 'https://raw.githubusercontent.com/nibir-d7/taured/master/cli/taured-win/taured.ps1')) {
        try {
            `$tauredPayload = (Invoke-WebRequest -UseBasicParsing -Uri `$tauredCandidate -TimeoutSec 60).Content
            break
        } catch { }
    }
    if (-not `$tauredPayload) { throw 'taured: could not download the Windows toolbox' }
    `$remoteScript = [ScriptBlock]::Create(`$tauredPayload)
    & `$remoteScript @invokeParameters
}
"@

    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($bootstrap))
}

if (!($SelfTest) -and !([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "taured needs to be run as Administrator. Attempting to relaunch."
    $elevationParameters = @{}
    foreach ($parameter in $PSBoundParameters.GetEnumerator()) {
        $elevationParameters[$parameter.Key] = if ($parameter.Value -is [switch]) {
            [bool]$parameter.Value
        } else {
            $parameter.Value
        }
    }

    $powershellCmd = if (Get-Command pwsh -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
    $powershellStaArgs = if ($powershellCmd -eq "pwsh") { @("-STA") } else { @() }

    # A headless caller is waiting on this process for an outcome, so the elevated run has to be
    # waited on and its code handed back. A terminal tab is skipped for the same reason: the
    # exit code of wt.exe is its own, not the run's.
    if ($Config -or $Preset) {
        # A declined UAC prompt throws, which would leave $elevated null and exit 0: the caller
        # waiting on this process would read that as a successful run
        try {
            $elevationCommand = New-tauredElevationCommand -ScriptPath $PSCommandPath -Parameters $elevationParameters -Headless
            $elevated = Start-Process $powershellCmd -ArgumentList ($powershellStaArgs + @("-ExecutionPolicy", "Bypass", "-NoProfile", "-EncodedCommand", $elevationCommand)) -Verb RunAs -Wait -PassThru -ErrorAction Stop
        } catch {
            Write-Host "Elevation was declined or failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "taured needs an Administrator PowerShell window." -ForegroundColor Yellow
            $global:LASTEXITCODE = 1
            if ($script:tauredIsFileProcess) {
                if (-not $env:TAURED_NO_PAUSE) { $null = Read-Host "Press Enter to close" }
                exit 1
            }
            return 1
        }
        $global:LASTEXITCODE = $elevated.ExitCode
        if ($script:tauredIsFileProcess) { exit $elevated.ExitCode }
        return $elevated.ExitCode
    }

    $processCmd = if (Get-Command wt.exe -ErrorAction SilentlyContinue) { "wt.exe" } else { "$powershellCmd" }
    $elevationCommand = New-tauredElevationCommand -ScriptPath $PSCommandPath -Parameters $elevationParameters

    if ($processCmd -eq "wt.exe") {
        Start-Process $processCmd -ArgumentList "$powershellCmd $($powershellStaArgs -join ' ') -ExecutionPolicy Bypass -NoProfile -EncodedCommand $elevationCommand" -Verb RunAs
    } else {
        Start-Process $processCmd -ArgumentList ($powershellStaArgs + @("-ExecutionPolicy", "Bypass", "-NoProfile", "-EncodedCommand", $elevationCommand)) -Verb RunAs
    }

    break
}

# Variable to sync between runspaces
$sync = [Hashtable]::Synchronized(@{})
$sync.version = "26.10.06"
$sync.IsLocalCompile = "false" -eq "true"
$sync.configs = @{}
$sync.Buttons = [System.Collections.Generic.List[PSObject]]::new()
$sync.preferences = @{}
# Name of the job currently running, or $null when idle. Owned by Start-tauredJob.
$sync.ActiveJob = $null
# Serializes worker-pool startup with recycling and shutdown.
$sync.RunspacePoolLock = [object]::new()
# Serializes the speculative and UI-thread taskbar overlay renderers.
$sync.AssetRenderLock = [object]::new()
$sync.RenderedAssetCache = [Hashtable]::Synchronized(@{})
# Every step recorded by Measure-tauredStep, from any thread
$sync.StepTimings = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
# Every error logged, so a job can report that something went wrong even when it did not throw
$sync.LoggedErrors = [System.Collections.ArrayList]::Synchronized([System.Collections.ArrayList]::new())
$sync.StartedAt = Get-Date
$sync.selectedAppx = [System.Collections.Generic.List[string]]::new()
$sync.selectedApps = [System.Collections.Generic.List[string]]::new()
$sync.selectedTweaks = [System.Collections.Generic.List[string]]::new()
$sync.selectedToggles = [System.Collections.Generic.List[string]]::new()
$sync.selectedFeatures = [System.Collections.Generic.List[string]]::new()
$sync.currentTab = "Install"

$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$taureddir = "$env:LocalAppData\taured"
$sync.taureddir = $taureddir

$logdir = "$taureddir\logs"
# Start-Transcript fails outright when the directory is missing, which is every first run
if (-not (Test-Path $logdir)) {
    New-Item -ItemType Directory -Path $logdir -Force | Out-Null
}
# Keep console output and structured entries in the path reported to the user. Write-tauredLog
# writes through the host while this transcript owns the file, avoiding competing file handles.
$sync.logPath = "$logdir\taured_$dateTime.log"
$sync.transcriptPath = $sync.logPath
Start-Transcript -Path $sync.transcriptPath -Append -NoClobber | Out-Null

$Host.UI.RawUI.WindowTitle = "taured"
Clear-Host
function Invoke-tauredApps {
    [OutputType([string[]])]
    param([hashtable]$Configs, [string[]]$Ids)

    $log = @()
    if (-not $Ids -or $Ids.Count -eq 0) { return $log }

    $winget = @()
    $choco = @()
    $missing = @()

    foreach ($id in $Ids) {
        $app = $Configs.applications.$id
        if (-not $app) {
            $missing += $id
            continue
        }
        if ($app.winget) { $winget += $app.winget } elseif ($app.choco) { $choco += $app.choco }
    }

    if ($winget.Count -gt 0) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $log += "winget is not installed. Open https://get.microsoft.com/winget and run again."
        } else {
            foreach ($package in $winget) {
                $log += "winget install $package"
                $output = & winget install --id $package -e --source winget --accept-package-agreements --accept-source-agreements 2>&1
                $log += ($output | Out-String).Trim()
                if ($LASTEXITCODE -ne 0) { $log += "failed: $package" }
            }
        }
    }

    foreach ($package in $choco) {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            $log += "choco install $package"
            $output = & choco install $package -y 2>&1
            $log += ($output | Out-String).Trim()
        } else {
            $log += "choco is not installed, skipped $package"
        }
    }

    if ($missing.Count -gt 0) { $log += "not in the catalog: $($missing -join ', ')" }
    return $log
}

function Invoke-tauredTweak {
    [OutputType([string[]])]
    param($Tweak, [switch]$Undo)

    $log = @()
    if (-not $Tweak) { return $log }

    $valueKey = if ($Undo) { "OriginalValue" } else { "Value" }

    foreach ($entry in @($Tweak.registry)) {
        if (-not $entry) { continue }
        $path = $entry.Path
        $name = $entry.Name
        $value = $entry.$valueKey

        if (-not (Test-Path $path)) {
            if ($Undo) { continue }
            New-Item -Path $path -Force | Out-Null
            $log += "created $path"
        }

        if ($value -eq "<RemoveEntry>") {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
            $log += "removed $path\$name"
            continue
        }

        $kind = switch ($entry.Type) {
            "DWord" { [Microsoft.Win32.RegistryValueKind]::DWord }
            "QWord" { [Microsoft.Win32.RegistryValueKind]::QWord }
            "Binary" { [Microsoft.Win32.RegistryValueKind]::Binary }
            "MultiString" { [Microsoft.Win32.RegistryValueKind]::MultiString }
            "ExpandString" { [Microsoft.Win32.RegistryValueKind]::ExpandString }
            default { [Microsoft.Win32.RegistryValueKind]::String }
        }

        $typedValue = $value
        if ($entry.Type -eq "DWord") { $typedValue = [int]$value }
        elseif ($entry.Type -eq "QWord") { $typedValue = [long]$value }
        elseif ($entry.Type -in @("Binary", "MultiString")) { $typedValue = $entry.($valueKey) }

        New-ItemProperty -Path $path -Name $name -Value $typedValue -PropertyType $kind -Force | Out-Null
        $log += "set $path\$name"
    }

    foreach ($entry in @($Tweak.service)) {
        if (-not $entry) { continue }
        $name = if ($entry.Name) { $entry.Name } else { $entry.name }
        $startup = if ($Undo) { $entry.OriginalType } else { $entry.StartupType }
        if (-not $name -or -not $startup) { continue }

        $service = Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $service) {
            $log += "service $name not present, skipped"
            continue
        }

        try {
            $wmi = Get-WmiObject -Class Win32_Service -Filter "Name='$name'" -ErrorAction Stop
            switch ($startup) {
                "Disabled" { $wmi.ChangeStartType("Disabled") }
                "Manual" { $wmi.ChangeStartType("Manual") }
                "Automatic" { $wmi.ChangeStartType("Automatic") }
            }
            $log += "service $name set to $startup"
        } catch {
            $log += "could not change service ${name}: $($_.Exception.Message)"
        }
    }

    $scriptKey = if ($Undo) { "UndoScript" } else { "InvokeScript" }
    $scriptText = $Tweak.$scriptKey
    if ($scriptText) {
        $log += ($scriptText | Out-String).Trim()
        Invoke-Expression $scriptText
    }

    $preKey = if ($Undo) { "UndoPre" } else { "InvokePre" }
    $preScript = $Tweak.$preKey
    if ($preScript) {
        $log += ($preScript | Out-String).Trim()
        Invoke-Expression $preScript
    }

    return $log
}

function Invoke-tauredTweaks {
    [OutputType([string[]])]
    param([hashtable]$Configs, [string[]]$Ids, [switch]$Undo)

    $log = @()
    if (-not $Ids -or $Ids.Count -eq 0) { return $log }

    foreach ($id in $Ids) {
        $tweak = $Configs.tweaks.$id
        if (-not $tweak) {
            $log += "not in the catalog: $id"
            continue
        }
        $log += if ($Undo) { "undo: $($tweak.Content)" } else { "apply: $($tweak.Content)" }
        $log += Invoke-tauredTweak -Tweak $tweak -Undo:$Undo
    }

    return $log
}

function Invoke-tauredFeature {
    [OutputType([string[]])]
    param($Feature)

    $log = @()
    if (-not $Feature) { return $log }

    $undo = $Feature.Undo
    $script = if ($undo) { $Feature.UndoScript } else { $Feature.script }
    if (-not $script) { $script = $Feature.InvokeScript }

    if (-not $script) {
        $log += "This feature has no script in the catalog."
        return $log
    }

    foreach ($command in @($script)) {
        $line = [string]$command
        if (-not $line.Trim()) { continue }
        $log += "> $line"
        try {
            Invoke-Expression $line 2>&1 | ForEach-Object { $log += "$_" }
        } catch {
            $log += "failed: $($_.Exception.Message)"
        }
    }

    return $log
}

function New-tauredRestorePoint {
    [OutputType([string])]
    param([string]$Description = "Before taured")

    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction Stop | Out-Null
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        return "restore point created"
    } catch {
        return "restore point skipped: $($_.Exception.Message)"
    }
}

function Start-tauredJob {
    param([hashtable]$Ui)

    if ($Ui.Running) { return }
    $Ui.Running = $true
    $Ui.Rows["status"].Text = "Working..."

    $apps = @($Ui.SelectedApps.Keys)
    $tweaks = @($Ui.SelectedTweaks.Keys)
    $configs = $Ui.Configs

    $log = @()
    $log += New-tauredRestorePoint
    $log += Invoke-tauredApps -Configs $configs -Ids $apps
    $log += Invoke-tauredTweaks -Configs $configs -Ids $tweaks

    Show-tauredLog -Ui $Ui -Lines $log
    $Ui.Running = $false
}

function Start-tauredUndoJob {
    param([hashtable]$Ui)

    if ($Ui.Running) { return }
    $Ui.Running = $true
    $Ui.Rows["status"].Text = "Undoing..."

    $log = Invoke-tauredTweaks -Configs $Ui.Configs -Ids @($Ui.SelectedTweaks.Keys) -Undo
    Show-tauredLog -Ui $Ui -Lines $log
    $Ui.Running = $false
}

function Show-tauredLog {
    param([hashtable]$Ui, [string[]]$Lines)

    $window = New-Object System.Windows.Window
    $window.Title = "taured"
    $window.Width = 820
    $window.Height = 560
    $window.WindowStartupLocation = "CenterScreen"
    $window.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Background)
    $window.WindowStyle = "None"
    $window.AllowsTransparency = $true
    $window.Background = [System.Windows.Media.Brushes]::Transparent

    $card = New-tauredCard -Palette $Ui.Palette
    $card.Margin = New-Object System.Windows.Thickness(20)
    $stack = New-Object System.Windows.Controls.StackPanel
    $stack.Children.Add((New-tauredTextBlock -Text "taured" -Color $Ui.Palette.Accent -Size 15 -Bold)) | Out-Null

    $box = New-Object System.Windows.Controls.TextBox
    $box.Text = ($Lines -join [Environment]::NewLine)
    $box.IsReadOnly = $true
    $box.AcceptsReturn = $true
    $box.TextWrapping = [System.Windows.TextWrapping]::NoWrap
    $box.VerticalScrollBarVisibility = "Auto"
    $box.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Background)
    $box.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Foreground)
    $box.BorderThickness = New-Object System.Windows.Thickness(0)
    $box.FontFamily = New-Object System.Windows.Media.FontFamily("Consolas")
    $box.FontSize = 12
    $box.Margin = New-Object System.Windows.Thickness(0, 12, 0, 0)
    $stack.Children.Add($box) | Out-Null

    $close = New-tauredButton -Text "Done" -Palette $Ui.Palette -Primary -Width 120
    $close.HorizontalAlignment = "Right"
    $close.Margin = New-Object System.Windows.Thickness(0, 14, 0, 0)
    $close.Add_Click({ $window.Close() })
    $stack.Children.Add($close) | Out-Null

    $card.Child = $stack
    $window.Content = $card
    $window.ShowDialog() | Out-Null
}
function New-tauredRow {
    param([double]$Height = 0, [switch]$Star)

    $row = New-Object System.Windows.Controls.RowDefinition
    $row.Height = if ($Star) {
        [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    } else {
        [System.Windows.GridLength]::new($Height)
    }
    return $row
}

function New-tauredColumn {
    param([double]$Width = 0, [switch]$Star)

    $column = New-Object System.Windows.Controls.ColumnDefinition
    $column.Width = if ($Star) {
        [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
    } else {
        [System.Windows.GridLength]::new($Width)
    }
    return $column
}

function Get-tauredPalette {
    [OutputType([hashtable])]
    param([switch]$Light)

    if ($Light) {
        return @{
            Background = "#FFFFFF"; Panel = "#F7F7F8"; Border = "#E4E4E7"
            Foreground = "#18181B"; Muted = "#71717A"; Accent = "#BE123C"
            AccentHover = "#E11D48"; Selected = "#FCE7EF"
        }
    }

    return @{
        Background = "#16181A"; Panel = "#1D2023"; Border = "#2A2E33"
        Foreground = "#F4F4F5"; Muted = "#8B8B92"; Accent = "#E11D48"
        AccentHover = "#FB7185"; Selected = "#2A1B21"
    }
}

function New-tauredTextBlock {
    param(
        [string]$Text,
        [string]$Color = "#FFFFFF",
        [double]$Size = 13,
        [switch]$Bold,
        [string]$Font = "Segoe UI"
    )

    $block = New-Object System.Windows.Controls.TextBlock
    $block.Text = $Text
    $block.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Color)
    $block.FontSize = $Size
    $block.FontFamily = New-Object System.Windows.Media.FontFamily($Font)
    if ($Bold) { $block.FontWeight = [System.Windows.FontWeights]::SemiBold }
    $block.TextWrapping = [System.Windows.TextWrapping]::NoWrap
    return $block
}

function New-tauredButton {
    param(
        [string]$Text,
        [hashtable]$Palette,
        [switch]$Primary,
        [int]$Width = 150
    )

    $button = New-Object System.Windows.Controls.Button
    $button.Content = $Text
    $button.Width = $Width
    $button.Height = 34
    $button.Cursor = [System.Windows.Input.Cursors]::Hand
    $button.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")
    $button.FontSize = 13

    if ($Primary) {
        $button.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Accent)
        $button.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#FFF1F2")
        $button.BorderThickness = [System.Windows.Thickness]::new(0)
    } else {
        $button.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Panel)
        $button.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Foreground)
        $button.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Border)
        $button.BorderThickness = [System.Windows.Thickness]::new(1)
    }

    return $button
}

function New-tauredCard {
    param([hashtable]$Palette, [double]$Height = 0)

    $border = New-Object System.Windows.Controls.Border
    $border.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Panel)
    $border.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Border)
    $border.BorderThickness = [System.Windows.Thickness]::new(1)
    $border.CornerRadius = New-Object System.Windows.CornerRadius(12)
    $border.Padding = New-Object System.Windows.Thickness(16)
    if ($Height -gt 0) { $border.Height = $Height }
    return $border
}

function New-tauredInterface {
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][hashtable]$Configs,
        [Parameter(Mandatory)][hashtable]$Palette,
        [string]$Version = "0.1.0"
    )

    $ui = @{
        Palette = $Palette
        Configs = $Configs
        Version = $Version
        Tab = "install"
        SelectedApps = @{}
        SelectedTweaks = @{}
        Search = ""
        Category = "All"
        Rows = @{}
        Detail = $null
        Status = "Ready"
        Running = $false
    }

    $window = New-Object System.Windows.Window
    $window.Title = "taured"
    $window.Width = 1180
    $window.Height = 760
    $window.MinWidth = 940
    $window.MinHeight = 620
    $window.WindowStartupLocation = "CenterScreen"
    $window.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Background)
    $window.FontFamily = New-Object System.Windows.Media.FontFamily("Segoe UI")
    $window.WindowStyle = "None"
    $window.AllowsTransparency = $true
    $window.Background = [System.Windows.Media.Brushes]::Transparent

    $shell = New-Object System.Windows.Controls.Grid
    $shell.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Background)
    $shell.RowDefinitions.Add((New-tauredRow -Height 64))
    $shell.RowDefinitions.Add((New-tauredRow -Star))
    $shell.RowDefinitions.Add((New-tauredRow -Height 52))
    $shell.RowDefinitions.Add((New-tauredRow -Height 30))
    $window.Content = $shell

    $header = New-Object System.Windows.Controls.Grid
    $header.Margin = New-Object System.Windows.Thickness(24, 14, 24, 10)
    $header.ColumnDefinitions.Add((New-tauredColumn -Star))
    $header.ColumnDefinitions.Add((New-tauredColumn -Width 1))

    $brand = New-Object System.Windows.Controls.StackPanel
    $brand.Orientation = "Horizontal"
    $brand.VerticalAlignment = "Center"
    $mark = New-Object System.Windows.Shapes.Ellipse
    $mark.Width = 26
    $mark.Height = 26
    $mark.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)
    $mark.Fill = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Accent)
    $brand.Children.Add($mark) | Out-Null
    $titleStack = New-Object System.Windows.Controls.StackPanel
    $titleStack.VerticalAlignment = "Center"
    $titleStack.Children.Add((New-tauredTextBlock -Text "taured" -Color $Palette.Accent -Size 20 -Bold)) | Out-Null
    $titleStack.Children.Add((New-tauredTextBlock -Text "windows toolbox" -Color $Palette.Muted -Size 11)) | Out-Null
    $brand.Children.Add($titleStack) | Out-Null
    $header.Children.Add($brand) | Out-Null

    $close = New-tauredButton -Text "Close" -Palette $Palette -Width 80
    $close.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($close, 1) | Out-Null
    $close.Add_Click({ $window.Close() })
    $header.Children.Add($close) | Out-Null
    [System.Windows.Controls.Grid]::SetRow($header, 0) | Out-Null
    $shell.Children.Add($header) | Out-Null

    $body = New-Object System.Windows.Controls.Grid
    $body.Margin = New-Object System.Windows.Thickness(24, 0, 24, 0)
    $body.ColumnDefinitions.Add((New-tauredColumn -Width 190))
    $body.ColumnDefinitions.Add((New-tauredColumn -Star))
    [System.Windows.Controls.Grid]::SetRow($body, 1) | Out-Null
    $shell.Children.Add($body) | Out-Null

    $sidebar = New-Object System.Windows.Controls.StackPanel
    $sidebar.Margin = New-Object System.Windows.Thickness(0, 0, 18, 0)
    foreach ($entry in @(
            @{ Key = "install"; Label = "Install apps" },
            @{ Key = "tweaks"; Label = "System tweaks" },
            @{ Key = "updates"; Label = "Updates" },
            @{ Key = "config"; Label = "Config" })) {
        $tabButton = New-tauredButton -Text $entry.Label -Palette $Palette -Width 172
        $tabButton.HorizontalAlignment = "Left"
        $tabButton.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
        $tabButton.Tag = $entry.Key
        $tabButton.Add_Click({
                param($sender, $eventArgs)
                Set-tauredTab -Ui $ui -Tab $sender.Tag
                Show-tauredTab -Ui $ui -Window $window -Sidebar $sidebar -Content $content
            }.GetNewClosure())
        $sidebar.Children.Add($tabButton) | Out-Null
        $ui.Rows["tab_$($entry.Key)"] = $tabButton
    }
    $body.Children.Add($sidebar) | Out-Null

    $content = New-Object System.Windows.Controls.Grid
    $content.ColumnDefinitions.Add((New-tauredColumn -Star))
    $content.ColumnDefinitions.Add((New-tauredColumn -Width 320))
    [System.Windows.Controls.Grid]::SetColumn($content, 1) | Out-Null
    $body.Children.Add($content) | Out-Null

    $ui.Rows["sidebar"] = $sidebar
    $ui.Rows["content"] = $content
    $ui.Rows["window"] = $window

    $actions = New-Object System.Windows.Controls.StackPanel
    $actions.Orientation = "Horizontal"
    $actions.HorizontalAlignment = "Right"
    $actions.VerticalAlignment = "Center"
    $actions.Margin = New-Object System.Windows.Thickness(24, 8, 24, 4)
    $ui.Rows["actions"] = $actions
    [System.Windows.Controls.Grid]::SetRow($actions, 2) | Out-Null
    $shell.Children.Add($actions) | Out-Null

    $footer = New-Object System.Windows.Controls.Grid
    $footer.Margin = New-Object System.Windows.Thickness(24, 0, 24, 8)
    $footer.ColumnDefinitions.Add((New-tauredColumn -Star))
    $footer.ColumnDefinitions.Add((New-tauredColumn -Width 1))
    $credit = New-tauredTextBlock -Text "based on WinUtil by Chris Titus Tech" -Color $Palette.Muted -Size 11
    $credit.VerticalAlignment = "Center"
    $footer.Children.Add($credit) | Out-Null
    $status = New-tauredTextBlock -Text "Ready" -Color $Palette.Muted -Size 11
    $status.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($status, 1) | Out-Null
    $footer.Children.Add($status) | Out-Null
    [System.Windows.Controls.Grid]::SetRow($footer, 3) | Out-Null
    $shell.Children.Add($footer) | Out-Null
    $ui.Rows["status"] = $status
    $ui.Rows["footer"] = $footer

    $window.Add_MouseLeftButtonDown({
            param($sender, $eventArgs)
            if ($eventArgs.ButtonState -eq "Pressed") { $window.DragMove() }
        }.GetNewClosure())

    Set-tauredTab -Ui $ui -Tab "install"
    Show-tauredTab -Ui $ui -Window $window -Sidebar $sidebar -Content $content

    return @{ Window = $window; Ui = $ui }
}

function Set-tauredTab {
    param([hashtable]$Ui, [string]$Tab)

    $Ui.Tab = $Tab
    foreach ($key in $Ui.Rows.Keys) {
        if ($key -like "tab_*") {
            $Ui.Rows[$key].BorderThickness = if ($key -eq "tab_$Tab") {
                New-Object System.Windows.Thickness(0, 0, 0, 2)
            } else {
                New-Object System.Windows.Thickness(0)
            }
        }
    }
}

function Show-tauredTab {
    param([hashtable]$Ui, [System.Windows.Window]$Window, $Sidebar, $Content)

    $Content.Children.Clear()

    switch ($Ui.Tab) {
        "install" { Add-tauredInstallView -Ui $Ui -Content $Content }
        "tweaks" { Add-tauredTweaksView -Ui $Ui -Content $Content }
        "updates" { Add-tauredUpdatesView -Ui $Ui -Content $Content }
        "config" { Add-tauredConfigView -Ui $Ui -Content $Content }
    }

    $Ui.Rows["actions"].Children.Clear()
    switch ($Ui.Tab) {
        "install" { $Ui.Rows["actions"].Children.Add((New-tauredRunButton -Ui $Ui -Label "Install selected")) | Out-Null }
        "tweaks" {
            $Ui.Rows["actions"].Children.Add((New-tauredRunButton -Ui $Ui -Label "Apply selected")) | Out-Null
            $Ui.Rows["actions"].Children.Add((New-tauredUndoButton -Ui $Ui)) | Out-Null
        }
        "config" {
            $Ui.Rows["actions"].Children.Add((New-tauredExportButton -Ui $Ui)) | Out-Null
            $Ui.Rows["actions"].Children.Add((New-tauredImportButton -Ui $Ui)) | Out-Null
        }
    }
}

function New-tauredRunButton {
    param([hashtable]$Ui, [string]$Label)

    $palette = $Ui.Palette
    $button = New-tauredButton -Text $Label -Palette $palette -Primary -Width 190
    $button.Add_Click({
            Start-tauredJob -Ui $Ui
        }.GetNewClosure())
    return $button
}

function New-tauredUndoButton {
    param([hashtable]$Ui)

    $button = New-tauredButton -Text "Undo selected" -Palette $Ui.Palette -Width 150
    $button.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
    $button.Add_Click({
            Start-tauredUndoJob -Ui $Ui
        }.GetNewClosure())
    return $button
}

function New-tauredExportButton {
    param([hashtable]$Ui)

    $button = New-tauredButton -Text "Export selection" -Palette $Ui.Palette -Width 170
    $button.Add_Click({
            Export-tauredSelection -Ui $Ui
        }.GetNewClosure())
    return $button
}

function New-tauredImportButton {
    param([hashtable]$Ui)

    $button = New-tauredButton -Text "Import selection" -Palette $Ui.Palette -Width 170
    $button.Margin = New-Object System.Windows.Thickness(10, 0, 0, 0)
    $button.Add_Click({
            Import-tauredSelection -Ui $Ui
        }.GetNewClosure())
    return $button
}
function Add-tauredInstallView {
    param([hashtable]$Ui, $Content)

    $left = New-Object System.Windows.Controls.Grid
    $left.RowDefinitions.Add((New-tauredRow -Height 44))
    $left.RowDefinitions.Add((New-tauredRow -Height 38))
    $left.RowDefinitions.Add((New-tauredRow -Star))

    $search = New-Object System.Windows.Controls.TextBox
    $search.Height = 36
    $search.FontSize = 13
    $search.Padding = New-Object System.Windows.Thickness(10, 6, 10, 6)
    $search.Background = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Panel)
    $search.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Foreground)
    $search.BorderBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Border)
    $search.CaretBrush = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Accent)
    $search.VerticalContentAlignment = "Center"
    $uiScope = $Ui
    $search.Add_TextChanged({
            param($sender, $eventArgs)
            $uiScope.Search = $sender.Text
            Add-tauredInstallList -Ui $uiScope -List $list
        })
    [System.Windows.Controls.Grid]::SetRow($search, 0) | Out-Null
    $left.Children.Add($search) | Out-Null

    $chips = New-Object System.Windows.Controls.ItemsControl
    $categories = @("All") + (@($Ui.Configs.applications.PSObject.Properties | ForEach-Object { $_.Value.category }) | Sort-Object -Unique)
    $chips.ItemsSource = $categories
    $chipPanel = New-Object System.Windows.Controls.StackPanel
    $chipPanel.Orientation = "Horizontal"
    $chipTemplate = @"
<DataTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
  <Button Content='{Binding}' Padding='12,6' Margin='0,0,8,0' Cursor='Hand' FontSize='12' />
</DataTemplate>
"@
    $chips.ItemTemplate = [System.Windows.Markup.XamlReader]::Parse($chipTemplate)
    [System.Windows.Controls.Grid]::SetRow($chips, 1) | Out-Null
    $left.Children.Add($chips) | Out-Null

    $list = New-Object System.Windows.Controls.ListBox
    $list.Background = [System.Windows.Media.Brushes]::Transparent
    $list.BorderThickness = New-Object System.Windows.Thickness(0)
    $list.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Foreground)
    [System.Windows.Controls.Grid]::SetRow($list, 2) | Out-Null
    $left.Children.Add($list) | Out-Null

    $rowTemplate = @"
<DataTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
  <Border Margin='0,0,0,4' CornerRadius='8' Padding='10,8'>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width='26' />
        <ColumnDefinition Width='*' />
        <ColumnDefinition Width='Auto' />
      </Grid.ColumnDefinitions>
      <CheckBox IsChecked='{Binding Selected}' VerticalAlignment='Center' />
      <StackPanel Grid.Column='1' Margin='8,0,0,0'>
        <TextBlock Text='{Binding Name}' FontSize='13.5' />
        <TextBlock Text='{Binding Category}' FontSize='11' Opacity='0.6' />
      </StackPanel>
      <TextBlock Grid.Column='2' Text='{Binding Source}' FontSize='11' Opacity='0.55' VerticalAlignment='Center' />
    </Grid>
  </Border>
</DataTemplate>
"@
    $list.ItemTemplate = [System.Windows.Markup.XamlReader]::Parse($rowTemplate)
    $uiScope = $Ui
    $list.Add_SelectionChanged({
            param($sender, $eventArgs)
            if ($sender.SelectedItem) { Update-tauredDetail -Ui $uiScope -Entry $sender.SelectedItem }
        })

    $Content.Children.Add($left) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($left, 0) | Out-Null

    $detail = New-tauredCard -Palette $Ui.Palette
    $detail.Margin = New-Object System.Windows.Thickness(18, 0, 0, 0)
    $detailText = New-Object System.Windows.Controls.StackPanel
    $detailText.Children.Add((New-tauredTextBlock -Text "Select an app" -Color $Ui.Palette.Muted -Size 13)) | Out-Null
    $detail.Child = $detailText
    $Ui.Rows["detail"] = $detail
    $Content.Children.Add($detail) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($detail, 1) | Out-Null

    $Ui.Rows["list"] = $list
    Add-tauredInstallList -Ui $Ui -List $list
}

function Add-tauredInstallList {
    param([hashtable]$Ui, $List)

    $entries = @()
    foreach ($property in $Ui.Configs.applications.PSObject.Properties) {
        $app = $property.Value
        if ($Ui.Category -ne "All" -and $app.category -ne $Ui.Category) { continue }
        if ($Ui.Search -and $app.content -notlike "*$($Ui.Search)*" -and $app.description -notlike "*$($Ui.Search)*") { continue }

        $source = if ($app.winget) { "winget" } elseif ($app.choco) { "choco" } else { "store" }
        $entries += [pscustomobject]@{
            Id = $property.Name
            Name = $app.content
            Category = $app.category
            Source = $source
            Description = $app.description
            Link = $app.link
            Selected = [bool]$Ui.SelectedApps[$property.Name]
            Tag = $Ui.Tab
        }
    }

    $List.ItemsSource = @($entries | Sort-Object Name)
}

function Update-tauredDetail {
    param([hashtable]$Ui, $Entry)

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Children.Add((New-tauredTextBlock -Text $Entry.Name -Color $Ui.Palette.Foreground -Size 17 -Bold)) | Out-Null
    $panel.Children.Add((New-tauredTextBlock -Text $Entry.Category -Color $Ui.Palette.Muted -Size 12)) | Out-Null

    $spacer = New-Object System.Windows.Controls.Spacer
    $spacer.Height = 10
    $panel.Children.Add($spacer) | Out-Null

    $description = New-tauredTextBlock -Text $Entry.Description -Color $Ui.Palette.Foreground -Size 12.5
    $description.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $panel.Children.Add($description) | Out-Null

    $spacer2 = New-Object System.Windows.Controls.Spacer
    $spacer2.Height = 12
    $panel.Children.Add($spacer2) | Out-Null

    $panel.Children.Add((New-tauredTextBlock -Text "Installed with $($Entry.Source)" -Color $Ui.Palette.Muted -Size 11)) | Out-Null

    $toggle = New-Object System.Windows.Controls.CheckBox
    $toggle.Content = "Include in this run"
    $toggle.Margin = New-Object System.Windows.Thickness(0, 14, 0, 0)
    $toggle.IsChecked = $Ui.SelectedApps[$Entry.Id]
    $toggle.Add_Click({
            param($sender, $eventArgs)
            $Ui.SelectedApps[$Entry.Id] = [bool]$sender.IsChecked
            Add-tauredInstallList -Ui $Ui -List $Ui.Rows["list"]
        }.GetNewClosure())
    $panel.Children.Add($toggle) | Out-Null

    if ($Entry.Link) {
        $link = New-Object System.Windows.Controls.TextBlock
        $link.Text = $Entry.Link
        $link.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Accent)
        $link.FontSize = 11.5
        $link.Margin = New-Object System.Windows.Thickness(0, 12, 0, 0)
        $link.TextDecorations = "Underline"
        $link.MouseLeftButtonUp.Add({
                Start-Process $Entry.Link
            }.GetNewClosure())
        $panel.Children.Add($link) | Out-Null
    }

    $Ui.Rows["detail"].Child = $panel
}

function Add-tauredTweaksView {
    param([hashtable]$Ui, $Content)

    $grid = New-Object System.Windows.Controls.Grid
    $grid.ColumnDefinitions.Add((New-tauredColumn -Star))
    $grid.ColumnDefinitions.Add((New-tauredColumn -Width 320))

    $list = New-Object System.Windows.Controls.ListBox
    $list.Background = [System.Windows.Media.Brushes]::Transparent
    $list.BorderThickness = New-Object System.Windows.Thickness(0)

    $entries = @()
    foreach ($property in $Ui.Configs.tweaks.PSObject.Properties) {
        $tweak = $property.Value
        $entries += [pscustomobject]@{
            Id = $property.Name
            Name = $tweak.Content
            Category = $tweak.category
            Selected = [bool]$Ui.SelectedTweaks[$property.Name]
        }
    }
    $list.ItemsSource = @($entries | Sort-Object Category, Name)

    $rowTemplate = @"
<DataTemplate xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'>
  <Border Margin='0,0,0,4' CornerRadius='8' Padding='10,8'>
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width='26' />
        <ColumnDefinition Width='*' />
        <ColumnDefinition Width='Auto' />
      </Grid.ColumnDefinitions>
      <CheckBox IsChecked='{Binding Selected}' VerticalAlignment='Center' />
      <StackPanel Grid.Column='1' Margin='8,0,0,0'>
        <TextBlock Text='{Binding Name}' FontSize='13.5' />
        <TextBlock Text='{Binding Category}' FontSize='11' Opacity='0.6' />
      </StackPanel>
      <TextBlock Grid.Column='2' Text='change' FontSize='11' Opacity='0.55' VerticalAlignment='Center' />
    </Grid>
  </Border>
</DataTemplate>
"@
    $list.ItemTemplate = [System.Windows.Markup.XamlReader]::Parse($rowTemplate)
    $uiScope = $Ui
    $list.Add_SelectionChanged({
            param($sender, $eventArgs)
            if ($sender.SelectedItem) {
                $entry = $sender.SelectedItem
                $tweak = $uiScope.Configs.tweaks.$($entry.Id)
                Update-tauredDetail -Ui $uiScope -Entry ([pscustomobject]@{
                        Name        = $entry.Name
                        Category    = $tweak.category
                        Description = $tweak.Description
                        Source      = (Format-tauredTweakSummary -Tweak $tweak)
                        Link        = $null
                    })
            }
        })

    $Content.Children.Add($list) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($list, 0) | Out-Null

    $detail = New-tauredCard -Palette $Ui.Palette
    $detail.Margin = New-Object System.Windows.Thickness(18, 0, 0, 0)
    $text = New-Object System.Windows.Controls.StackPanel
    $text.Children.Add((New-tauredTextBlock -Text "Select a tweak" -Color $Ui.Palette.Muted -Size 13)) | Out-Null
    $detail.Child = $text
    $Ui.Rows["detail"] = $detail
    $Content.Children.Add($detail) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($detail, 1) | Out-Null
    $Ui.Rows["tweaksList"] = $list
}

function Format-tauredTweakSummary {
    param($Tweak)

    $parts = @()
    if ($Tweak.registry) { $parts += "$($Tweak.registry.Count) registry" }
    if ($Tweak.service) { $parts += "$($Tweak.service.Count) service" }
    if ($Tweak.appx) { $parts += "$($Tweak.appx.Count) app" }
    if ($Tweak.InvokeScript) { $parts += "script" }
    if ($parts.Count -eq 0) { return "no changes" }
    return ($parts -join ", ")
}

function Add-tauredUpdatesView {
    param([hashtable]$Ui, $Content)

    $uiScope = $Ui
    $panel = New-Object System.Windows.Controls.StackPanel

    foreach ($property in $Ui.Configs.feature.PSObject.Properties) {
        $feature = $property.Value
        $card = New-tauredCard -Palette $Ui.Palette
        $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 12)
        $stack = New-Object System.Windows.Controls.StackPanel
        $stack.Children.Add((New-tauredTextBlock -Text $feature.Content -Color $Ui.Palette.Foreground -Size 14 -Bold)) | Out-Null
        $description = New-tauredTextBlock -Text $feature.Description -Color $Ui.Palette.Muted -Size 12
        $description.TextWrapping = [System.Windows.TextWrapping]::Wrap
        $stack.Children.Add($description) | Out-Null
        $stack.Children.Add((New-tauredTextBlock -Text "Changes $($property.Name) settings" -Color $Ui.Palette.Muted -Size 11)) | Out-Null

        $runnable = $feature.script -or $feature.InvokeScript
        if ($runnable) {
            $run = New-tauredButton -Text "Run" -Palette $Ui.Palette -Width 90
            $run.HorizontalAlignment = "Left"
            $run.Margin = New-Object System.Windows.Thickness(0, 10, 0, 0)
            $featureId = $property.Name
            $run.Add_Click({
                    $log = @((New-tauredRestorePoint))
                    $log += Invoke-tauredFeature -Feature $uiScope.Configs.feature.$featureId
                    Show-tauredLog -Ui $uiScope -Lines $log
                }.GetNewClosure())
            $stack.Children.Add($run) | Out-Null
        }

        $card.Child = $stack
        $panel.Children.Add($card) | Out-Null
    }

    $Content.Children.Add($panel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($panel, 0) | Out-Null

    $detail = New-tauredCard -Palette $Ui.Palette
    $detail.Margin = New-Object System.Windows.Thickness(18, 0, 0, 0)
    $note = New-Object System.Windows.Controls.StackPanel
    $note.Children.Add((New-tauredTextBlock -Text "Before you start" -Color $Ui.Palette.Foreground -Size 15 -Bold)) | Out-Null
    $note.Children.Add((New-tauredTextBlock -Text "taured creates a restore point before any change and every tweak keeps its previous value so it can be undone." -Color $Ui.Palette.Muted -Size 12)) | Out-Null
    $detail.Child = $note
    $Content.Children.Add($detail) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($detail, 1) | Out-Null
}

function Add-tauredConfigView {
    param([hashtable]$Ui, $Content)

    $panel = New-Object System.Windows.Controls.StackPanel
    $panel.Children.Add((New-tauredTextBlock -Text "Selection" -Color $Ui.Palette.Foreground -Size 16 -Bold)) | Out-Null

    $summary = New-tauredTextBlock -Text "Apps: $($Ui.SelectedApps.Count)   Tweaks: $($Ui.SelectedTweaks.Count)" -Color $Ui.Palette.Muted -Size 12.5
    $summary.Margin = New-Object System.Windows.Thickness(0, 8, 0, 0)
    $panel.Children.Add($summary) | Out-Null

    $hint = New-tauredTextBlock -Text "Export writes a JSON file with your current picks. Import reads one back, so a machine setup can be reproduced anywhere." -Color $Ui.Palette.Muted -Size 12
    $hint.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $hint.Margin = New-Object System.Windows.Thickness(0, 14, 0, 0)
    $panel.Children.Add($hint) | Out-Null

    $logButton = New-tauredButton -Text "Open log folder" -Palette $Ui.Palette -Width 170
    $logButton.HorizontalAlignment = "Left"
    $logButton.Margin = New-Object System.Windows.Thickness(0, 18, 0, 0)
    $logButton.Add_Click({
            Start-Process (Join-Path $env:LOCALAPPDATA "taured\logs")
        }.GetNewClosure())
    $panel.Children.Add($logButton) | Out-Null

    $Content.Children.Add($panel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($panel, 0) | Out-Null

    $about = New-tauredCard -Palette $Ui.Palette
    $about.Margin = New-Object System.Windows.Thickness(18, 0, 0, 0)
    $aboutStack = New-Object System.Windows.Controls.StackPanel
    $aboutStack.Children.Add((New-tauredTextBlock -Text "taured" -Color $Ui.Palette.Accent -Size 16 -Bold)) | Out-Null
    $aboutStack.Children.Add((New-tauredTextBlock -Text "Free, open, no login." -Color $Ui.Palette.Muted -Size 12)) | Out-Null
    $aboutStack.Children.Add((New-tauredTextBlock -Text "based on WinUtil by Chris Titus Tech" -Color $Ui.Palette.Muted -Size 11)) | Out-Null
    $about.Child = $aboutStack
    $Content.Children.Add($about) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($about, 1) | Out-Null
}

function Export-tauredSelection {
    param([hashtable]$Ui)

    $payload = @{
        apps = @($Ui.SelectedApps.Keys)
        tweaks = @($Ui.SelectedTweaks.Keys)
        version = $Ui.Version
    }

    $path = Join-Path ([Environment]::GetFolderPath("Desktop")) "taured-selection.json"
    $payload | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
    $Ui.Rows["status"].Text = "Exported to $path"
}

function Import-tauredSelection {
    param([hashtable]$Ui)

    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Filter = "JSON files (*.json)|*.json"
    if ($dialog.ShowDialog() -ne $true) { return }

    $payload = Get-Content $dialog.FileName -Raw | ConvertFrom-Json
    $Ui.SelectedApps = @{}
    foreach ($id in @($payload.apps)) { $Ui.SelectedApps[$id] = $true }
    $Ui.SelectedTweaks = @{}
    foreach ($id in @($payload.tweaks)) { $Ui.SelectedTweaks[$id] = $true }

    if ($Ui.Rows["list"]) { Add-tauredInstallList -Ui $Ui -List $Ui.Rows["list"] }
    $Ui.Rows["status"].Text = "Imported $($Ui.SelectedApps.Count) apps and $($Ui.SelectedTweaks.Count) tweaks"
}
$sync.configs.applications = @'
{
  "1password": {
    "category": "Utilities",
    "choco": "1password",
    "content": "1Password",
    "description": "1Password is a password manager that allows you to store and manage your passwords securely.",
    "link": "https://1password.com/",
    "winget": "AgileBits.1Password",
    "foss": false
  },
  "7zip": {
    "category": "Utilities",
    "choco": "7zip",
    "content": "7-Zip",
    "description": "7-Zip is a free and open-source file archiver utility. It supports several compression formats and provides a high compression ratio, making it a popular choice for file compression.",
    "link": "https://www.7-zip.org/",
    "winget": "7zip.7zip",
    "foss": true
  },
  "abdownloadmanager": {
    "category": "Utilities",
    "choco": "ab-download-manager",
    "content": "AB Download Manager",
    "description": "AB Download Manager is an open-source download accelerator and manager with multi-threaded downloads, queue scheduling, speed limiting, and browser integration.",
    "link": "https://abdownloadmanager.com/",
    "winget": "amir1376.ABDownloadManager",
    "foss": true
  },
  "adobe": {
    "category": "Document",
    "choco": "adobereader",
    "content": "Adobe Acrobat Reader",
    "description": "Adobe Acrobat Reader is a free PDF viewer with essential features for viewing, printing, and annotating PDF documents.",
    "link": "https://www.adobe.com/acrobat/pdf-reader.html",
    "winget": "Adobe.Acrobat.Reader.64-bit",
    "foss": false
  },
  "advancedip": {
    "category": "Pro Tools",
    "choco": "advanced-ip-scanner",
    "content": "Advanced IP Scanner",
    "description": "Advanced IP Scanner is a fast and easy-to-use network scanner. It is designed to analyze LAN networks and provides information about connected devices.",
    "link": "https://www.advanced-ip-scanner.com/",
    "winget": "Famatech.AdvancedIPScanner",
    "foss": false
  },
  "aimp": {
    "category": "Multimedia Tools",
    "choco": "aimp",
    "content": "AIMP (Music Player)",
    "description": "AIMP is a feature-rich music player with support for various audio formats, playlists, and customizable user interface.",
    "link": "https://www.aimp.ru/",
    "winget": "AIMP.AIMP",
    "foss": false
  },
  "angryipscanner": {
    "category": "Pro Tools",
    "choco": "angryip",
    "content": "Angry IP Scanner",
    "description": "Angry IP Scanner is an open-source and cross-platform network scanner. It is used to scan IP addresses and ports, providing information about network connectivity.",
    "link": "https://angryip.org/",
    "winget": "angryziber.AngryIPScanner",
    "foss": true
  },
  "anydesk": {
    "category": "Utilities",
    "choco": "anydesk",
    "content": "AnyDesk",
    "description": "AnyDesk is a remote desktop software that enables users to access and control computers remotely. It is known for its fast connection and low latency.",
    "link": "https://anydesk.com/",
    "winget": "AnyDesk.AnyDesk",
    "foss": false
  },
  "audacity": {
    "category": "Multimedia Tools",
    "choco": "audacity",
    "content": "Audacity",
    "description": "Audacity is a free and open-source audio editing software known for its powerful recording and editing capabilities.",
    "link": "https://www.audacityteam.org/",
    "winget": "Audacity.Audacity",
    "foss": true
  },
  "autoruns": {
    "category": "Microsoft Tools",
    "choco": "autoruns",
    "content": "Autoruns",
    "description": "This utility shows you what programs are configured to run during system bootup or login.",
    "link": "https://learn.microsoft.com/en-us/sysinternals/downloads/autoruns",
    "winget": "Microsoft.Sysinternals.Autoruns",
    "foss": false
  },
  "rdcman": {
    "category": "Microsoft Tools",
    "choco": "rdcman",
    "content": "RDCMan",
    "description": "RDCMan manages multiple remote desktop connections. It is useful for managing server labs where you need regular access to each machine such as automated checkin systems and data centers.",
    "link": "https://learn.microsoft.com/en-us/sysinternals/downloads/rdcman",
    "winget": "Microsoft.Sysinternals.RDCMan",
    "foss": false
  },
  "autohotkey": {
    "category": "Utilities",
    "choco": "autohotkey",
    "content": "AutoHotkey",
    "description": "AutoHotkey is a scripting language for Windows that allows users to create custom automation scripts and macros. It is often used for automating repetitive tasks and customizing keyboard shortcuts.",
    "link": "https://www.autohotkey.com/",
    "winget": "AutoHotkey.AutoHotkey",
    "foss": true
  },
  "battlenet": {
    "category": "Games",
    "choco": "na",
    "winget": "Blizzard.BattleNet",
    "content": "Battle.net",
    "description": "Battle.net is a launcher for games created and developed by Activision Blizzard",
    "link": "https://battle.net",
    "foss": false
  },
  "bitwarden": {
    "category": "Utilities",
    "choco": "bitwarden",
    "content": "Bitwarden",
    "description": "Bitwarden is an open-source password management solution. It allows users to store and manage their passwords in a secure and encrypted vault, accessible across multiple devices.",
    "link": "https://bitwarden.com/",
    "winget": "Bitwarden.Bitwarden",
    "foss": true
  },
  "blender": {
    "category": "Multimedia Tools",
    "choco": "blender",
    "content": "Blender (3D Graphics)",
    "description": "Blender is a powerful open-source 3D creation suite, offering modeling, sculpting, animation, and rendering tools.",
    "link": "https://www.blender.org/",
    "winget": "BlenderFoundation.Blender",
    "foss": true
  },
  "brave": {
    "category": "Browsers",
    "choco": "brave",
    "content": "Brave",
    "description": "Brave is a privacy-focused web browser that blocks ads and trackers, offering a faster and safer browsing experience.",
    "link": "https://www.brave.com",
    "winget": "Brave.Brave",
    "foss": true
  },
  "bruno": {
    "category": "Development",
    "choco": "bruno",
    "content": "Bruno",
    "description": "Bruno is a local-first API client that stores collections as plain text files for version control and collaboration.",
    "link": "https://www.usebruno.com/",
    "winget": "Bruno.Bruno",
    "foss": true
  },
  "bulkcrapuninstaller": {
    "category": "Utilities",
    "choco": "bulk-crap-uninstaller",
    "content": "Bulk Crap Uninstaller",
    "description": "Bulk Crap Uninstaller is a free and open-source uninstaller utility for Windows. It helps users remove unwanted programs and clean up their system by uninstalling multiple applications at once.",
    "link": "https://www.bcuninstaller.com/",
    "winget": "Klocman.BulkCrapUninstaller",
    "foss": true
  },
  "blurautoclicker": {
    "category": "Utilities",
    "choco": "na",
    "content": "BlurAutoClicker",
    "description": "An Auto-clicker with a few advanced features and generally better performance than popular alternatives.",
    "link": "https://blur009.vercel.app/projects/blur-autoclicker/",
    "winget": "Blur009.BlurAutoClicker",
    "foss": true
  },
  "calibre": {
    "category": "Multimedia Tools",
    "choco": "calibre",
    "content": "Calibre",
    "description": "Calibre is a powerful and easy-to-use e-book manager, viewer, and converter.",
    "link": "https://calibre-ebook.com/",
    "winget": "calibre.calibre",
    "foss": true
  },
  "cemu": {
    "category": "Games",
    "choco": "cemu",
    "content": "Cemu",
    "description": "Cemu is a highly experimental software to emulate Wii U applications on PC.",
    "link": "https://cemu.info/",
    "winget": "Cemu.Cemu",
    "foss": true
  },
  "chatgpt": {
    "category": "Development",
    "choco": "na",
    "content": "ChatGPT Desktop",
    "description": "The official ChatGPT desktop app for Windows, distributed through the Microsoft Store.",
    "link": "https://openai.com/chatgpt/download/",
    "winget": "msstore:9NT1R1C2HH7J",
    "foss": false
  },
  "chatterino": {
    "category": "Communications",
    "choco": "chatterino",
    "content": "Chatterino",
    "description": "Chatterino is a chat client for Twitch chat that offers a clean and customizable interface for a better streaming experience.",
    "link": "https://www.chatterino.com/",
    "winget": "ChatterinoTeam.Chatterino",
    "foss": true
  },
  "chrome": {
    "category": "Browsers",
    "choco": "googlechrome",
    "content": "Chrome",
    "description": "Google Chrome is a widely used web browser known for its speed, simplicity, and seamless integration with Google services.",
    "link": "https://www.google.com/chrome/",
    "winget": "Google.Chrome",
    "foss": false
  },
  "chromium": {
    "category": "Browsers",
    "choco": "chromium",
    "content": "Chromium",
    "description": "Chromium is the open-source project that serves as the foundation for various web browsers, including Chrome.",
    "link": "https://www.chromium.org/",
    "winget": "Hibbiki.Chromium",
    "foss": true
  },
  "cinebenchr23": {
    "category": "Pro Tools",
    "choco": "na",
    "content": "Cinebench R23",
    "description": "Cinebench R23 is a benchmark tool for comparing CPU rendering performance across systems.",
    "link": "https://www.maxon.net/en/cinebench",
    "winget": "Maxon.CinebenchR23",
    "foss": false
  },
  "claude": {
    "category": "Development",
    "choco": "claude",
    "content": "Claude Desktop",
    "description": "Anthropic's Claude desktop application for focused AI-assisted work and chat.",
    "link": "https://claude.ai/download",
    "winget": "Anthropic.Claude",
    "foss": false
  },
  "claude-code": {
    "category": "Development",
    "choco": "claude-code",
    "content": "Claude Code",
    "description": "Anthropic's agentic coding tool for terminal and IDE development workflows.",
    "link": "https://code.claude.com/",
    "winget": "Anthropic.ClaudeCode",
    "foss": false
  },
  "cmake": {
    "category": "Development",
    "choco": "cmake",
    "content": "CMake",
    "description": "CMake is an open-source, cross-platform family of tools designed to build, test and package software.",
    "link": "https://cmake.org/",
    "winget": "Kitware.CMake",
    "foss": true
  },
  "codex": {
    "category": "Development",
    "choco": "codex",
    "content": "Codex",
    "description": "Codex CLI is an OpenAI coding agent that runs locally in your terminal.",
    "link": "https://developers.openai.com/codex/cli",
    "winget": "OpenAI.Codex",
    "foss": true
  },
  "cpuz": {
    "category": "Pro Tools",
    "choco": "cpu-z",
    "content": "CPU-Z",
    "description": "CPU-Z is a system monitoring and diagnostic tool for Windows. It provides detailed information about the computer's hardware components, including the CPU, memory, and motherboard.",
    "link": "https://www.cpuid.com/softwares/cpu-z.html",
    "winget": "CPUID.CPU-Z",
    "foss": false
  },
  "crystaldiskinfo": {
    "category": "Utilities",
    "choco": "crystaldiskinfo",
    "content": "Crystal Disk Info",
    "description": "Crystal Disk Info is a disk health monitoring tool that provides information about the status and performance of hard drives. It helps users anticipate potential issues and monitor drive health.",
    "link": "https://crystalmark.info/en/software/crystaldiskinfo/",
    "winget": "CrystalDewWorld.CrystalDiskInfo",
    "foss": true
  },
  "crystaldiskmark": {
    "category": "Utilities",
    "choco": "crystaldiskmark",
    "content": "Crystal Disk Mark",
    "description": "Crystal Disk Mark is a disk benchmarking tool that measures the read and write speeds of storage devices. It helps users assess the performance of their hard drives and SSDs.",
    "link": "https://crystalmark.info/en/software/crystaldiskmark/",
    "winget": "CrystalDewWorld.CrystalDiskMark",
    "foss": true
  },
  "cursor": {
    "category": "Development",
    "choco": "cursoride",
    "content": "Cursor",
    "description": "AI-powered code editor (VS Code-based) with agentic coding features and integrated AI assistance for development workflows.",
    "link": "https://cursor.com/",
    "winget": "Anysphere.Cursor",
    "foss": false
  },
  "ddu": {
    "category": "Pro Tools",
    "choco": "ddu",
    "content": "Display Driver Uninstaller",
    "description": "Display Driver Uninstaller (DDU) is a tool for completely uninstalling graphics drivers from NVIDIA, AMD, and Intel. It is useful for troubleshooting graphics driver-related issues.",
    "link": "https://www.wagnardsoft.com/display-driver-uninstaller-DDU-",
    "winget": "Wagnardsoft.DisplayDriverUninstaller",
    "foss": true
  },
  "discord": {
    "category": "Communications",
    "choco": "discord",
    "content": "Discord",
    "description": "Discord is a popular communication platform with voice, video, and text chat, designed for gamers but used by a wide range of communities.",
    "link": "https://discord.com/",
    "winget": "Discord.Discord",
    "foss": false
  },
  "dismtools": {
    "category": "Microsoft Tools",
    "choco": "dismtools",
    "content": "DISMTools",
    "description": "DISMTools is a fast, customizable GUI for the DISM utility, supporting Windows images from Windows 7 onward. It handles installations on any drive, offers project support, and lets users tweak settings like color modes, language, and DISM versions; powered by both native DISM and a managed DISM API.",
    "link": "https://github.com/CodingWonders/DISMTools",
    "winget": "CodingWondersSoftware.DISMTools.Stable",
    "foss": true
  },
  "ntlite": {
    "category": "Microsoft Tools",
    "choco": "ntlite-free",
    "content": "NTLite",
    "description": "Integrate updates, drivers, automate Windows and application setup, speedup Windows deployment process and have it all set for the next time.",
    "link": "https://ntlite.com",
    "winget": "Nlitesoft.NTLite",
    "foss": false
  },
  "dorion": {
    "category": "Communications",
    "choco": "dorion",
    "content": "Dorion",
    "description": "Tiny alternative Discord client with a smaller footprint, snappier startup, themes, plugins and more!",
    "link": "https://spikehd.dev/projects/dorion/",
    "winget": "SpikeHD.Dorion",
    "foss": true
  },
  "dockerdesktop": {
    "category": "Development",
    "choco": "docker-desktop",
    "content": "Docker Desktop",
    "description": "Docker Desktop provides a local environment for building, running, and testing containerized applications on Windows.",
    "link": "https://www.docker.com/products/docker-desktop/",
    "winget": "Docker.DockerDesktop",
    "foss": false
  },
  "dotnet6": {
    "category": "Microsoft Tools",
    "choco": "dotnet-6.0-runtime",
    "content": ".NET Desktop Runtime 6",
    "description": ".NET Desktop Runtime 6 is a runtime environment required for running applications developed with .NET 6.",
    "link": "https://dotnet.microsoft.com/download/dotnet/6.0",
    "winget": "Microsoft.DotNet.DesktopRuntime.6",
    "foss": true
  },
  "dotnet8": {
    "category": "Microsoft Tools",
    "choco": "dotnet-8.0-runtime",
    "content": ".NET Desktop Runtime 8",
    "description": ".NET Desktop Runtime 8 is a runtime environment required for running applications developed with .NET 8.",
    "link": "https://dotnet.microsoft.com/download/dotnet/8.0",
    "winget": "Microsoft.DotNet.DesktopRuntime.8",
    "foss": true
  },
  "dotnet9": {
    "category": "Microsoft Tools",
    "choco": "dotnet-9.0-runtime",
    "content": ".NET Desktop Runtime 9",
    "description": ".NET Desktop Runtime 9 is a runtime environment required for running applications developed with .NET 9.",
    "link": "https://dotnet.microsoft.com/download/dotnet/9.0",
    "winget": "Microsoft.DotNet.DesktopRuntime.9",
    "foss": true
  },
  "dotnet10": {
    "category": "Microsoft Tools",
    "choco": "dotnet-10.0-runtime",
    "content": ".NET Desktop Runtime 10",
    "description": ".NET Desktop Runtime 10 is a runtime environment required for running applications developed with .NET 10.",
    "link": "https://dotnet.microsoft.com/download/dotnet/10.0",
    "winget": "Microsoft.DotNet.DesktopRuntime.10",
    "foss": true
  },
  "dropbox": {
    "category": "Utilities",
    "choco": "dropbox",
    "content": "Dropbox",
    "description": "Dropbox is a cloud storage client for syncing files, sharing content, and keeping documents available across devices.",
    "link": "https://www.dropbox.com/desktop",
    "winget": "Dropbox.Dropbox",
    "foss": false
  },
  "eaapp": {
    "category": "Games",
    "choco": "ea-app",
    "content": "EA App",
    "description": "EA App is a platform for accessing and playing Electronic Arts games.",
    "link": "https://www.ea.com/ea-app",
    "winget": "ElectronicArts.EADesktop",
    "foss": false
  },
  "eartrumpet": {
    "category": "Multimedia Tools",
    "choco": "eartrumpet",
    "content": "EarTrumpet (Audio)",
    "description": "EarTrumpet is an audio control app for Windows, providing a simple and intuitive interface for managing sound settings.",
    "link": "https://eartrumpet.app/",
    "winget": "File-New-Project.EarTrumpet",
    "foss": true
  },
  "edge": {
    "category": "Browsers",
    "choco": "microsoft-edge",
    "content": "Edge",
    "description": "Microsoft Edge is a modern web browser built on Chromium, offering performance, security, and integration with Microsoft services.",
    "link": "https://www.microsoft.com/edge",
    "winget": "Microsoft.Edge",
    "foss": false
  },
  "es-de": {
    "category": "Games",
    "choco": "",
    "content": "EmulationStation Desktop Edition",
    "_comment": "This and emulationstation are two completely different things. ES-DE is your frontend for everything and has its own set of emulators. Emulationstation is a graphical frontend for RetroArch.",
    "description": "EmulationStation Desktop Edition is a frontend for browsing and launching games from your multi-platform game collection.",
    "link": "https://es-de.org/",
    "winget": "ES-DE.EmulationStation-DE",
    "foss": true
  },
  "enteauth": {
    "category": "Utilities",
    "choco": "ente-auth",
    "content": "Ente Auth",
    "description": "Ente Auth is a free, cross-platform, end-to-end encrypted authenticator app.",
    "link": "https://ente.io/auth/",
    "winget": "ente-io.auth-desktop",
    "foss": true
  },
  "epicgames": {
    "category": "Games",
    "choco": "epicgameslauncher",
    "content": "Epic Games Launcher",
    "description": "Epic Games Launcher is the client for accessing and playing games from the Epic Games Store.",
    "link": "https://www.epicgames.com/store/en-US/",
    "winget": "EpicGames.EpicGamesLauncher",
    "foss": false
  },
  "files": {
    "category": "Utilities",
    "choco": "files",
    "content": "Files",
    "description": "Alternative file explorer.",
    "link": "https://files.community",
    "winget": "FilesCommunity.Files",
    "foss": true
  },
  "fileconverter": {
    "category": "Multimedia Tools",
    "choco": "file-converter",
    "content": "File Converter",
    "description": "File Converter converts and compresses files from the Windows Explorer context menu.",
    "link": "https://file-converter.io/",
    "winget": "AdrienAllard.FileConverter",
    "foss": true
  },
  "firefox": {
    "category": "Browsers",
    "choco": "firefox",
    "content": "Firefox",
    "description": "Mozilla Firefox is an open-source web browser known for its customization options, privacy features, and extensions.",
    "link": "https://www.mozilla.org/en-US/firefox/new/",
    "winget": "Mozilla.Firefox",
    "foss": true
  },
  "firefoxesr": {
    "category": "Browsers",
    "choco": "FirefoxESR",
    "content": "Firefox ESR",
    "description": "Mozilla Firefox is an open-source web browser known for its customization options, privacy features, and extensions. Firefox ESR (Extended Support Release) receives major updates every 42 weeks with minor updates such as crash fixes, security fixes and policy updates as needed, but at least every four weeks.",
    "link": "https://www.mozilla.org/en-US/firefox/enterprise/",
    "winget": "Mozilla.Firefox.ESR",
    "foss": true
  },
  "floorp": {
    "category": "Browsers",
    "choco": "floorp",
    "content": "Floorp",
    "description": "Floorp is an open-source web browser project that aims to provide a simple and fast browsing experience.",
    "link": "https://floorp.app/",
    "winget": "Ablaze.Floorp",
    "foss": true
  },
  "flux": {
    "category": "Utilities",
    "choco": "flux",
    "content": "F.lux",
    "description": "f.lux adjusts the color temperature of your screen to reduce eye strain during nighttime use.",
    "link": "https://justgetflux.com/",
    "winget": "flux.flux",
    "foss": false
  },
  "foobar": {
    "category": "Multimedia Tools",
    "choco": "foobar2000",
    "content": "foobar2000 (Music Player)",
    "description": "foobar2000 is a highly customizable and extensible music player for Windows, known for its modular design and advanced features.",
    "link": "https://www.foobar2000.org/",
    "winget": "PeterPawlowski.foobar2000",
    "foss": false
  },
  "fnm": {
    "category": "Development",
    "choco": "fnm",
    "content": "Fast Node Manager",
    "description": "Fast Node Manager (fnm) is a fast, cross-platform tool for installing and switching between Node.js versions.",
    "link": "https://github.com/Schniz/fnm",
    "winget": "Schniz.fnm",
    "foss": true
  },
  "foxpdfreader": {
    "category": "Document",
    "choco": "foxitreader",
    "content": "Foxit PDF Reader",
    "description": "Foxit PDF Reader is a free PDF viewer with a familiar ribbon-style interface.",
    "link": "https://www.foxit.com/pdf-reader/",
    "winget": "Foxit.FoxitReader",
    "foss": false
  },
  "geforcenow": {
    "category": "Games",
    "choco": "nvidia-geforce-now",
    "content": "GeForce NOW",
    "description": "GeForce NOW is a cloud gaming service that allows you to play high-quality PC games on your device.",
    "link": "https://www.nvidia.com/en-us/geforce-now/",
    "winget": "Nvidia.GeForceNow",
    "foss": false
  },
  "gimp": {
    "category": "Multimedia Tools",
    "choco": "gimp",
    "content": "GIMP (Image Editor)",
    "description": "GIMP is a versatile open-source raster graphics editor used for tasks such as photo retouching, image editing, and image composition.",
    "link": "https://www.gimp.org/",
    "winget": "GIMP.GIMP.3",
    "foss": true
  },
  "git": {
    "category": "Development",
    "choco": "git",
    "content": "Git",
    "description": "Git is a distributed version control system widely used for tracking changes in source code during software development.",
    "link": "https://git-scm.com/",
    "winget": "Git.Git",
    "foss": true
  },
  "gitextensions": {
    "category": "Development",
    "choco": "gitextensions",
    "content": "Git Extensions",
    "description": "Git Extensions is a graphical Git client for Windows with repository, history, and commit management tools.",
    "link": "https://gitextensions.github.io/",
    "winget": "GitExtensionsTeam.GitExtensions",
    "foss": true
  },
  "githubcli": {
    "category": "Development",
    "choco": "gh",
    "content": "GitHub CLI",
    "description": "GitHub CLI brings pull requests, issues, releases, and other GitHub workflows to the terminal.",
    "link": "https://cli.github.com/",
    "winget": "GitHub.cli",
    "foss": true
  },
  "githubdesktop": {
    "category": "Development",
    "choco": "git;github-desktop",
    "content": "GitHub Desktop",
    "description": "GitHub Desktop is a visual Git client that simplifies collaboration on GitHub repositories with an easy-to-use interface.",
    "link": "https://desktop.github.com/",
    "winget": "GitHub.GitHubDesktop",
    "foss": true
  },
  "gog": {
    "category": "Games",
    "choco": "goggalaxy",
    "content": "GOG Galaxy",
    "description": "GOG Galaxy is a gaming client that offers DRM-free games, additional content, and more.",
    "link": "https://www.gog.com/galaxy",
    "winget": "GOG.Galaxy",
    "foss": false
  },
  "golang": {
    "category": "Development",
    "choco": "golang",
    "content": "Go",
    "description": "Go (or Golang) is a statically typed, compiled programming language designed for simplicity, reliability, and efficiency.",
    "link": "https://go.dev/",
    "winget": "GoLang.Go",
    "foss": true
  },
  "googledrive": {
    "category": "Utilities",
    "choco": "googledrive",
    "content": "Google Drive",
    "description": "File syncing across devices all tied to your Google account.",
    "link": "https://www.google.com/drive/",
    "winget": "Google.GoogleDrive",
    "foss": false
  },
  "gpuz": {
    "category": "Pro Tools",
    "choco": "gpu-z",
    "content": "GPU-Z",
    "description": "GPU-Z provides detailed information about your graphics card and GPU.",
    "link": "https://www.techpowerup.com/gpuz/",
    "winget": "TechPowerUp.GPU-Z",
    "foss": false
  },
  "gsudo": {
    "category": "Pro Tools",
    "choco": "gsudo",
    "content": "gsudo",
    "description": "gsudo is a sudo equivalent for Windows. It allows you to run commands with elevated administrative privileges directly within the current console window.",
    "link": "https://github.com/gerardog/gsudo",
    "winget": "gerardog.gsudo",
    "foss": true
  },
  "helium": {
    "category": "Browsers",
    "choco": "helium",
    "content": "Helium",
    "description": "Private, fast, and honest web browser.",
    "link": "https://helium.computer",
    "winget": "ImputNet.Helium",
    "foss": true
  },
  "hugo": {
    "category": "Utilities",
    "choco": "hugo-extended",
    "content": "Hugo",
    "description": "The world's fastest framework for building websites.",
    "link": "https://gohugo.io",
    "winget": "Hugo.Hugo.Extended",
    "foss": true
  },
  "handbrake": {
    "category": "Multimedia Tools",
    "choco": "handbrake",
    "content": "HandBrake",
    "description": "HandBrake is an open-source video transcoder, allowing you to convert video from nearly any format to a selection of widely supported codecs.",
    "link": "https://handbrake.fr/",
    "winget": "HandBrake.HandBrake",
    "foss": true
  },
  "heroiclauncher": {
    "category": "Games",
    "choco": "heroic-games-launcher",
    "content": "Heroic Games Launcher",
    "description": "Heroic Games Launcher is an open-source alternative game launcher for Epic Games Store.",
    "link": "https://heroicgameslauncher.com/",
    "winget": "HeroicGamesLauncher.HeroicGamesLauncher",
    "foss": true
  },
  "hwinfo": {
    "category": "Pro Tools",
    "choco": "hwinfo",
    "content": "HWiNFO",
    "description": "HWiNFO provides comprehensive hardware information and diagnostics for Windows.",
    "link": "https://www.hwinfo.com/",
    "winget": "REALiX.HWiNFO",
    "foss": false
  },
  "hwmonitor": {
    "category": "Pro Tools",
    "choco": "hwmonitor",
    "content": "HWMonitor",
    "description": "HWMonitor is a hardware monitoring program that reads PC systems main health sensors.",
    "link": "https://www.cpuid.com/softwares/hwmonitor.html",
    "winget": "CPUID.HWMonitor",
    "foss": false
  },
  "imageglass": {
    "category": "Multimedia Tools",
    "choco": "imageglass",
    "content": "ImageGlass (Image Viewer)",
    "description": "ImageGlass is a versatile image viewer with support for various image formats and a focus on simplicity and speed.",
    "link": "https://imageglass.org/",
    "winget": "DuongDieuPhap.ImageGlass",
    "foss": true
  },
  "internetdownloadmanager": {
    "category": "Utilities",
    "choco": "internet-download-manager",
    "content": "Internet Download Manager",
    "description": "Internet Download Manager is a download manager for accelerating, resuming, and scheduling file downloads.",
    "link": "https://www.internetdownloadmanager.com/",
    "winget": "Tonec.InternetDownloadManager",
    "foss": false
  },
  "irfanview": {
    "category": "Multimedia Tools",
    "choco": "irfanview",
    "content": "IrfanView",
    "description": "IrfanView is a lightweight, fast, and free image viewer and editor. Supports multiple formats, batch processing, and powerful plugins.",
    "link": "https://irfanview.com/",
    "winget": "IrfanSkiljan.IrfanView",
    "foss": false
  },
  "itch": {
    "category": "Games",
    "choco": "itch",
    "content": "Itch.io",
    "description": "Itch.io is a digital distribution platform for indie games and creative projects.",
    "link": "https://itch.io/",
    "winget": "ItchIo.Itch",
    "foss": true
  },
  "itunes": {
    "category": "Multimedia Tools",
    "choco": "itunes",
    "content": "iTunes",
    "description": "iTunes is a media player, media library, and online radio broadcaster application developed by Apple Inc.",
    "link": "https://www.apple.com/itunes/",
    "winget": "Apple.iTunes",
    "foss": false
  },
  "java8": {
    "category": "Development",
    "choco": "corretto8jdk",
    "content": "Amazon Corretto 8 (LTS)",
    "description": "Amazon Corretto is a no-cost, multiplatform, production-ready distribution of the Open Java Development Kit (OpenJDK).",
    "link": "https://aws.amazon.com/corretto",
    "winget": "Amazon.Corretto.8.JDK",
    "foss": true
  },
  "java21": {
    "category": "Development",
    "choco": "corretto21jdk",
    "content": "Amazon Corretto 21 (LTS)",
    "description": "Amazon Corretto is a no-cost, multiplatform, production-ready distribution of the Open Java Development Kit (OpenJDK).",
    "link": "https://aws.amazon.com/corretto",
    "winget": "Amazon.Corretto.21.JDK",
    "foss": true
  },
  "java25": {
    "category": "Development",
    "choco": "corretto25jdk",
    "content": "Amazon Corretto 25 (LTS)",
    "description": "Amazon Corretto is a no-cost, multiplatform, production-ready distribution of the Open Java Development Kit (OpenJDK).",
    "link": "https://aws.amazon.com/corretto",
    "winget": "Amazon.Corretto.25.JDK",
    "foss": true
  },
  "jellyfinmediaplayer": {
    "category": "Selfhosted Tools",
    "choco": "jellyfin-media-player",
    "content": "Jellyfin Media Player",
    "description": "Jellyfin Media Player is a client application for the Jellyfin media server, providing access to your media library.",
    "link": "https://jellyfin.org/",
    "winget": "Jellyfin.JellyfinMediaPlayer",
    "foss": true
  },
  "jellyfinserver": {
    "category": "Selfhosted Tools",
    "choco": "jellyfin",
    "content": "Jellyfin Server",
    "description": "Jellyfin Server is an open-source media server software, allowing you to organize and stream your media library.",
    "link": "https://jellyfin.org/",
    "winget": "Jellyfin.Server",
    "foss": true
  },
  "jetbrains": {
    "category": "Development",
    "choco": "jetbrainstoolbox",
    "content": "Jetbrains Toolbox",
    "description": "Jetbrains Toolbox is a platform for easy installation and management of JetBrains developer tools.",
    "link": "https://www.jetbrains.com/toolbox/",
    "winget": "JetBrains.Toolbox",
    "foss": false
  },
  "jpegview": {
    "category": "Utilities",
    "choco": "jpegview",
    "content": "JPEG View",
    "description": "JPEGView is a lean, fast and highly configurable viewer/editor for JPEG, BMP, PNG, WEBP, TGA, GIF, JXL, HEIC, HEIF, AVIF, and TIFF images with a minimal GUI.",
    "link": "https://github.com/sylikc/jpegview",
    "winget": "sylikc.JPEGView",
    "foss": true
  },
  "joplin": {
    "category": "Document",
    "choco": "joplin",
    "content": "Joplin",
    "description": "Joplin is an open-source note-taking and to-do application with synchronization capabilities.",
    "link": "https://joplinapp.org/",
    "winget": "Joplin.Joplin",
    "foss": true
  },
  "keepassxc": {
    "category": "Utilities",
    "choco": "keepassxc",
    "content": "KeePassXC",
    "description": "KeePassXC is a modern, secure, and open-source password manager that stores and manages your most sensitive information. You can run KeePassXC on Windows, macOS, and Linux systems. KeePassXC is for people with extremely high demands of secure personal data management. It saves many different types of information, such as usernames, passwords, URLs, attachments, and notes in an offline, encrypted file that can be stored in any location, including private and public cloud solutions. For easy identification and management, user-defined titles and icons can be specified for entries. In addition, entries are sorted into customizable groups. An integrated search function allows you to use advanced patterns to easily find any entry in your database. A customizable, fast, and easy-to-use password generator utility allows you to create passwords with any combination of characters or easy to remember passphrases.",
    "link": "https://keepassxc.org/",
    "winget": "KeePassXCTeam.KeePassXC",
    "foss": true
  },
  "klite": {
    "category": "Multimedia Tools",
    "choco": "k-litecodecpack-standard",
    "content": "K-Lite Codec Standard",
    "description": "K-Lite Codec Pack Standard is a collection of audio and video codecs and related tools, providing essential components for media playback.",
    "link": "https://www.codecguide.com/",
    "winget": "CodecGuide.K-LiteCodecPack.Standard",
    "foss": false
  },
  "kodi": {
    "category": "Selfhosted Tools",
    "choco": "kodi",
    "content": "Kodi Media Center",
    "description": "Kodi is an open-source media center application that allows you to play and view most videos, music, podcasts, and other digital media files.",
    "link": "https://kodi.tv/",
    "winget": "XBMCFoundation.Kodi",
    "foss": true
  },
  "lazygit": {
    "category": "Development",
    "choco": "lazygit",
    "content": "Lazygit",
    "description": "Simple terminal UI for git commands.",
    "link": "https://github.com/jesseduffield/lazygit/",
    "winget": "JesseDuffield.lazygit",
    "foss": true
  },
  "libreoffice": {
    "category": "Document",
    "choco": "libreoffice-fresh",
    "content": "LibreOffice",
    "description": "LibreOffice is a powerful and free office suite, compatible with other major office suites.",
    "link": "https://www.libreoffice.org/",
    "winget": "TheDocumentFoundation.LibreOffice",
    "foss": true
  },
  "librewolf": {
    "category": "Browsers",
    "choco": "librewolf",
    "content": "LibreWolf",
    "description": "LibreWolf is a privacy-focused web browser based on Firefox, with additional privacy and security enhancements.",
    "link": "https://librewolf.net/",
    "winget": "LibreWolf.LibreWolf",
    "foss": true
  },
  "localsend": {
    "category": "Selfhosted Tools",
    "choco": "localsend.install",
    "content": "LocalSend",
    "description": "An open-source cross-platform alternative to AirDrop.",
    "link": "https://localsend.org/",
    "winget": "LocalSend.LocalSend",
    "foss": true
  },
  "mpc-qt": {
    "category": "Multimedia Tools",
    "choco": "mediainfo",
    "content": "mpc-qt",
    "description": "Media Player Classic Qute Theater",
    "link": "https://mpc-qt.github.io",
    "winget": "mpc-qt.mpc-qt",
    "foss": true
  },
  "mpv": {
    "category": "Multimedia Tools",
    "content": "mpv",
    "description": "mpv is a free, open source, and cross-platform media player supporting a wide variety of media formats, codecs, and subtitle types.",
    "link": "https://mpv.io/",
    "winget": "shinchiro.mpv",
    "foss": true
  },
  "matrix": {
    "category": "Communications",
    "choco": "element-desktop",
    "content": "Element",
    "description": "Element is a client for Matrix; an open network for secure, decentralized communication.",
    "link": "https://element.io/",
    "winget": "Element.Element",
    "foss": true
  },
  "minitoolpartitionwizard": {
    "category": "Utilities",
    "choco": "minitoolpartitionwizard",
    "content": "MiniTool Partition Wizard",
    "description": "Comprehensive free partition manager that performs advanced operations Windows natively cannot, such as merging partitions, converting file systems, and organizing disk capacity.",
    "link": "https://www.partitionwizard.com/",
    "winget": "MiniTool.PartitionWizard.Free",
    "foss": false
  },
  "modrinth": {
    "category": "Games",
    "choco": "modrinth-app",
    "content": "Modrinth App",
    "description": "Modrinth App is a desktop application for managing Minecraft mods and modpacks.",
    "link": "https://modrinth.com/app",
    "winget": "Modrinth.ModrinthApp",
    "foss": true
  },
  "moonlight": {
    "category": "Selfhosted Tools",
    "choco": "moonlight-qt",
    "content": "Moonlight/GameStream Client",
    "description": "Moonlight/GameStream Client allows you to stream PC games to other devices over your local network.",
    "link": "https://moonlight-stream.org/",
    "winget": "MoonlightGameStreamingProject.Moonlight",
    "foss": true
  },
  "mpchc": {
    "category": "Multimedia Tools",
    "choco": "mpc-hc-clsid2",
    "content": "Media Player Classic - Home Cinema",
    "description": "Media Player Classic - Home Cinema (MPC-HC) is a free and open-source video and audio player for Windows. MPC-HC is based on the original Guliverkli project and contains many additional features and bug fixes.",
    "link": "https://mpc-hc.org/",
    "winget": "clsid2.mpc-hc",
    "foss": true
  },
  "msedgeredirect": {
    "category": "Utilities",
    "choco": "msedgeredirect",
    "content": "MSEdgeRedirect",
    "description": "A Tool to Redirect News, Search, Widgets, Weather, and More to your default browser.",
    "link": "https://github.com/rcmaehl/MSEdgeRedirect",
    "winget": "rcmaehl.MSEdgeRedirect",
    "foss": true
  },
  "msiafterburner": {
    "category": "Utilities",
    "choco": "msiafterburner",
    "content": "MSI Afterburner",
    "description": "MSI Afterburner is a graphics card overclocking utility with advanced features.",
    "link": "https://www.msi.com/Landing/afterburner",
    "winget": "Guru3D.Afterburner",
    "foss": false
  },
  "mullvadvpn": {
    "category": "Pro Tools",
    "choco": "mullvad-app",
    "content": "Mullvad VPN",
    "description": "This is the VPN client software for the Mullvad VPN service.",
    "link": "https://mullvad.net/",
    "winget": "MullvadVPN.MullvadVPN",
    "foss": true
  },
  "mullvadbrowser": {
    "category": "Browsers",
    "choco": "na",
    "content": "Mullvad Browser",
    "description": "Mullvad Browser is a privacy-focused web browser, developed in partnership with the Tor Project.",
    "link": "https://mullvad.net/browser",
    "winget": "MullvadVPN.MullvadBrowser",
    "foss": true
  },
  "nomacs": {
    "category": "Multimedia Tools",
    "choco": "nomacs",
    "content": "nomacs",
    "description": "nomacs is a free, open-source image viewer, which supports multiple platforms. You can use it for viewing all common image formats, including RAW and .psd images.",
    "link": "https://nomacs.org/",
    "winget": "nomacs.nomacs",
    "foss": true
  },
  "nanazip": {
    "category": "Utilities",
    "choco": "nanazip",
    "content": "NanaZip",
    "description": "NanaZip is a fast and efficient file compression and decompression tool.",
    "link": "https://nanazip.org",
    "winget": "M2Team.NanaZip",
    "foss": true
  },
  "netbird": {
    "category": "Selfhosted Tools",
    "choco": "netbird",
    "content": "NetBird",
    "description": "NetBird is an open-source alternative comparable to TailScale that can be connected to a self-hosted server.",
    "link": "https://netbird.io/",
    "winget": "Netbird.Netbird",
    "foss": true
  },
  "tailscale": {
    "category": "Utilities",
    "choco": "tailscale",
    "content": "Tailscale",
    "description": "The Tailscale client allows you to connect all your devices using WireGuard®, without the hassle. Tailscale makes it as easy as installing an app and signing in.",
    "link": "https://tailscale.com/",
    "winget": "Tailscale.Tailscale",
    "foss": false
  },
  "naps2": {
    "category": "Document",
    "choco": "naps2",
    "content": "NAPS2 (Scanner)",
    "description": "NAPS2 is a document scanning application that simplifies the process of creating electronic documents.",
    "link": "https://www.naps2.com/",
    "winget": "Cyanfish.NAPS2",
    "foss": true
  },
  "neovim": {
    "category": "Development",
    "choco": "neovim",
    "content": "Neovim",
    "description": "Neovim is a highly extensible text editor and an improvement over the original Vim editor.",
    "link": "https://neovim.io/",
    "winget": "Neovim.Neovim",
    "foss": true
  },
  "nextclouddesktop": {
    "category": "Selfhosted Tools",
    "choco": "nextcloud-client",
    "content": "Nextcloud Desktop",
    "description": "Nextcloud Desktop is the official desktop client for the Nextcloud file synchronization and sharing platform.",
    "link": "https://nextcloud.com/install/#install-clients",
    "winget": "Nextcloud.NextcloudDesktop",
    "foss": true
  },
  "nmap": {
    "category": "Pro Tools",
    "choco": "nmap",
    "content": "Nmap",
    "description": "Nmap (Network Mapper) is an open-source tool for network exploration and security auditing. It discovers devices on a network and provides information about their ports and services.",
    "link": "https://nmap.org/",
    "winget": "Insecure.Nmap",
    "foss": true
  },
  "nodejs": {
    "category": "Development",
    "choco": "nodejs",
    "content": "NodeJS",
    "description": "NodeJS is a JavaScript runtime built on Chrome's V8 JavaScript engine for building server-side and networking applications.",
    "link": "https://nodejs.org/",
    "winget": "OpenJS.NodeJS",
    "foss": true
  },
  "nodejslts": {
    "category": "Development",
    "choco": "nodejs-lts",
    "content": "NodeJS LTS",
    "description": "NodeJS LTS provides Long-Term Support releases for stable and reliable server-side JavaScript development.",
    "link": "https://nodejs.org/",
    "winget": "OpenJS.NodeJS.LTS",
    "foss": true
  },
  "pnpm": {
    "category": "Development",
    "content": "pnpm",
    "description": "pnpm is a fast and disk space efficient package manager for JavaScript and Node.js applications.",
    "link": "https://pnpm.io/",
    "winget": "pnpm.pnpm",
    "foss": true
  },
  "notepadplus": {
    "category": "Multimedia Tools",
    "choco": "notepadplusplus",
    "content": "Notepad++",
    "description": "Notepad++ is a free, open-source code editor and Notepad replacement with support for multiple languages.",
    "link": "https://notepad-plus-plus.org/",
    "winget": "Notepad++.Notepad++",
    "foss": true
  },
  "nuget": {
    "category": "Microsoft Tools",
    "choco": "nuget.commandline",
    "content": "NuGet",
    "description": "NuGet is a package manager for the .NET framework, enabling developers to manage and share libraries in their .NET applications.",
    "link": "https://www.nuget.org/",
    "winget": "Microsoft.NuGet",
    "foss": true
  },
  "nvclean": {
    "category": "Utilities",
    "choco": "na",
    "content": "NVCleanstall",
    "description": "NVCleanstall is a tool designed to customize NVIDIA driver installations, allowing advanced users to control more aspects of the installation process.",
    "link": "https://www.techpowerup.com/nvcleanstall/",
    "winget": "TechPowerUp.NVCleanstall",
    "foss": false
  },
  "obs": {
    "category": "Multimedia Tools",
    "choco": "obs-studio",
    "content": "OBS Studio",
    "description": "OBS Studio is a free and open-source software for video recording and live streaming. It supports real-time video/audio capturing and mixing, making it popular among content creators.",
    "link": "https://obsproject.com/",
    "winget": "OBSProject.OBSStudio",
    "foss": true
  },
  "obsidian": {
    "category": "Document",
    "choco": "obsidian",
    "content": "Obsidian",
    "description": "Obsidian is a powerful note-taking and knowledge management application.",
    "link": "https://obsidian.md/",
    "winget": "Obsidian.Obsidian",
    "foss": false
  },
  "okular": {
    "category": "Document",
    "choco": "okular",
    "content": "Okular",
    "description": "Okular is a versatile document viewer with advanced features.",
    "link": "https://okular.kde.org/",
    "winget": "KDE.Okular",
    "foss": true
  },
  "onedrive": {
    "category": "Microsoft Tools",
    "choco": "onedrive",
    "content": "OneDrive",
    "description": "OneDrive is a cloud storage service provided by Microsoft, allowing users to store and share files securely across devices.",
    "link": "https://onedrive.live.com/",
    "winget": "Microsoft.OneDrive",
    "foss": false
  },
  "onlyoffice": {
    "category": "Document",
    "choco": "onlyoffice",
    "content": "ONLYOFFICE Desktop",
    "description": "ONLYOFFICE Desktop is a comprehensive office suite for document editing and collaboration.",
    "link": "https://www.onlyoffice.com/desktop.aspx",
    "winget": "ONLYOFFICE.DesktopEditors",
    "foss": true
  },
  "OPAutoClicker": {
    "category": "Utilities",
    "choco": "autoclicker",
    "content": "OPAutoClicker",
    "description": "A full-fledged autoclicker with two modes of autoclicking, at your dynamic cursor location or at a prespecified location.",
    "link": "https://www.opautoclicker.com",
    "winget": "OPAutoClicker.OPAutoClicker",
    "foss": false
  },
  "openrgb": {
    "category": "Utilities",
    "choco": "openrgb",
    "content": "OpenRGB",
    "description": "OpenRGB is an open-source RGB lighting control software designed to manage and control RGB lighting for various components and peripherals.",
    "link": "https://openrgb.org/",
    "winget": "OpenRGB.OpenRGB",
    "foss": true
  },
  "OpenVPN": {
    "category": "Pro Tools",
    "choco": "openvpn-connect",
    "content": "OpenVPN Connect",
    "description": "OpenVPN Connect is a VPN client that allows you to connect securely to a VPN server. It provides a secure and encrypted connection for protecting your online privacy.",
    "link": "https://openvpn.net/",
    "winget": "OpenVPNTechnologies.OpenVPNConnect",
    "foss": false
  },
  "OVirtualBox": {
    "category": "Utilities",
    "choco": "virtualbox",
    "content": "Oracle VirtualBox",
    "description": "Oracle VirtualBox is a powerful and free open-source virtualization tool for x86 and AMD64/Intel64 architectures.",
    "link": "https://www.virtualbox.org/",
    "winget": "Oracle.VirtualBox",
    "foss": true
  },
  "policyplus": {
    "category": "Utilities",
    "choco": "na",
    "content": "Policy Plus",
    "description": "Local Group Policy Editor plus more, for all Windows editions.",
    "link": "https://github.com/Fleex255/PolicyPlus",
    "winget": "Fleex255.PolicyPlus",
    "foss": true
  },
  "processexplorer": {
    "category": "Microsoft Tools",
    "choco": "procexp",
    "content": "Process Explorer",
    "description": "Process Explorer is a task manager and system monitor.",
    "link": "https://learn.microsoft.com/sysinternals/downloads/process-explorer",
    "winget": "Microsoft.Sysinternals.ProcessExplorer",
    "foss": false
  },
  "Paintdotnet": {
    "category": "Multimedia Tools",
    "choco": "paint.net",
    "content": "Paint.NET",
    "description": "Paint.NET is a free image and photo editing software for Windows. It features an intuitive user interface and supports a wide range of powerful editing tools.",
    "link": "https://www.getpaint.net/",
    "winget": "dotPDN.PaintDotNet",
    "foss": false
  },
  "parsec": {
    "category": "Utilities",
    "choco": "parsec",
    "content": "Parsec",
    "description": "Parsec is a low-latency, high-quality remote desktop sharing application for collaborating and gaming across devices.",
    "link": "https://parsec.app/",
    "winget": "Parsec.Parsec",
    "foss": false
  },
  "peazip": {
    "category": "Utilities",
    "choco": "peazip",
    "content": "PeaZip",
    "description": "PeaZip is a free, open-source file archiver utility that supports multiple archive formats and provides encryption features.",
    "link": "https://peazip.github.io/",
    "winget": "Giorgiotani.Peazip",
    "foss": true
  },
  "pdf-xchange": {
    "category": "Document",
    "choco": "pdfxchangeeditor",
    "content": "PDF-XChange Editor",
    "description": "A comprehensive Windows-based software suite and editor for creating, viewing, editing, annotating, and signing PDF files.",
    "link": "https://www.pdf-xchange.com/",
    "winget": "TrackerSoftware.PDF-XChangeEditor",
    "foss": false
  },
  "pdf24creator": {
    "category": "Document",
    "choco": "pdf24",
    "content": "PDF24 Creator",
    "description": "Free and easy-to-use online/desktop PDF tools that make you more productive",
    "link": "https://tools.pdf24.org/en/creator",
    "winget": "geeksoftwareGmbH.PDF24Creator",
    "foss": false
  },
  "pdfgear": {
    "category": "Document",
    "choco": "pdfgear",
    "content": "PDFgear",
    "description": "PDFgear is a piece of full-featured PDF management software for Windows, macOS, and mobile, and it's completely free to use.",
    "link": "https://www.pdfgear.com/",
    "winget": "PDFgear.PDFgear",
    "foss": false
  },
  "pdfsam": {
    "category": "Document",
    "choco": "pdfsam",
    "content": "PDFsam Basic",
    "description": "PDFsam Basic is a free and open-source tool for splitting, merging, and rotating PDF files.",
    "link": "https://pdfsam.org/",
    "winget": "PDFsam.PDFsam",
    "foss": true
  },
  "playnite": {
    "category": "Games",
    "choco": "playnite",
    "content": "Playnite",
    "description": "Playnite is an open-source video game library manager with one simple goal: To provide a unified interface for all of your games.",
    "link": "https://playnite.link/",
    "winget": "Playnite.Playnite",
    "foss": true
  },
  "plex": {
    "category": "Selfhosted Tools",
    "choco": "plexmediaserver",
    "content": "Plex Media Server",
    "description": "Plex Media Server is a media server software that allows you to organize and stream your media library. It supports various media formats and offers a wide range of features.",
    "link": "https://www.plex.tv/your-media/",
    "winget": "Plex.PlexMediaServer",
    "foss": false
  },
  "plexdesktop": {
    "category": "Selfhosted Tools",
    "choco": "plex",
    "content": "Plex Desktop",
    "description": "Plex Desktop for Windows is the front end for Plex Media Server.",
    "link": "https://www.plex.tv",
    "winget": "Plex.Plex",
    "foss": false
  },
  "posh": {
    "category": "Development",
    "choco": "oh-my-posh",
    "content": "Oh My Posh (Prompt)",
    "description": "Oh My Posh is a cross-platform prompt theme engine for any shell.",
    "link": "https://ohmyposh.dev/",
    "winget": "JanDeDobbeleer.OhMyPosh",
    "foss": true
  },
  "postman": {
    "category": "Development",
    "choco": "postman",
    "content": "Postman",
    "description": "Postman is an API platform and desktop client for designing, testing, documenting, and collaborating on APIs.",
    "link": "https://www.postman.com/downloads/",
    "winget": "Postman.Postman",
    "foss": false
  },
  "powershell": {
    "category": "Microsoft Tools",
    "choco": "powershell-core",
    "content": "PowerShell",
    "description": "PowerShell is a task automation framework and scripting language designed for system administrators, offering powerful command-line capabilities.",
    "link": "https://github.com/PowerShell/PowerShell",
    "winget": "Microsoft.PowerShell",
    "foss": true
  },
  "powertoys": {
    "category": "Microsoft Tools",
    "choco": "powertoys",
    "content": "PowerToys",
    "description": "PowerToys is a set of utilities for power users to enhance productivity, featuring tools like FancyZones, PowerRename, and more.",
    "link": "https://github.com/microsoft/PowerToys",
    "winget": "Microsoft.PowerToys",
    "foss": true
  },
  "prismlauncher": {
    "category": "Games",
    "choco": "prismlauncher",
    "content": "Prism Launcher",
    "description": "Prism Launcher is an open-source Minecraft launcher with the ability to manage multiple instances, accounts, and mods.",
    "link": "https://prismlauncher.org/",
    "winget": "PrismLauncher.PrismLauncher",
    "foss": true
  },
  "processlasso": {
    "category": "Utilities",
    "choco": "plasso",
    "content": "Process Lasso",
    "description": "Process Lasso is a system optimization and automation tool that improves system responsiveness and stability by adjusting process priorities and CPU affinities.",
    "link": "https://bitsum.com/",
    "winget": "BitSum.ProcessLasso",
    "foss": false
  },
  "protonauth": {
    "category": "Utilities",
    "choco": "protonauth",
    "content": "Proton Authenticator",
    "description": "2FA app from Proton to securely sync and backup 2FA codes.",
    "link": "https://proton.me/authenticator",
    "winget": "Proton.ProtonAuthenticator",
    "foss": true
  },
  "protonmail": {
    "category": "Communications",
    "choco": "protonmail",
    "content": "Proton Mail",
    "description": "Proton Mail is an end-to-end encrypted email service by Proton, protecting your privacy with zero-access encryption.",
    "link": "https://proton.me/mail",
    "winget": "Proton.ProtonMail",
    "foss": true
  },
  "protondrive": {
    "category": "Utilities",
    "choco": "protondrive",
    "content": "Proton Drive",
    "description": "Proton Drive is an end-to-end encrypted Swiss vault for your files that protects your data.",
    "link": "https://proton.me/drive",
    "winget": "Proton.ProtonDrive",
    "foss": true
  },
  "protonpass": {
    "category": "Utilities",
    "choco": "protonpass",
    "content": "Proton Pass",
    "description": "Proton Pass is a cloud-based password manager with end-to-end encryption and unique email aliases.",
    "link": "https://proton.me/pass",
    "winget": "Proton.ProtonPass",
    "foss": true
  },
  "protonvpn": {
    "category": "Pro Tools",
    "choco": "protonvpn",
    "content": "Proton VPN",
    "description": "Proton VPN is a no-logs VPN service that protects your privacy online with features like Secure Core and Tor over VPN.",
    "link": "https://protonvpn.com/",
    "winget": "Proton.ProtonVPN",
    "foss": true
  },
  "processmonitor": {
    "category": "Microsoft Tools",
    "choco": "procexp",
    "content": "Process Monitor",
    "description": "SysInternals Process Monitor is an advanced monitoring tool that shows real-time file system, registry, and process/thread activity.",
    "link": "https://docs.microsoft.com/en-us/sysinternals/downloads/procmon",
    "winget": "Microsoft.Sysinternals.ProcessMonitor",
    "foss": false
  },
  "putty": {
    "category": "Pro Tools",
    "choco": "putty",
    "content": "PuTTY",
    "description": "PuTTY is a free and open-source terminal emulator, serial console, and network file transfer application. It supports various network protocols such as SSH, Telnet, and SCP.",
    "link": "https://www.chiark.greenend.org.uk/~sgtatham/putty/",
    "winget": "PuTTY.PuTTY",
    "foss": true
  },
  "python3": {
    "category": "Development",
    "choco": "python",
    "content": "Python3",
    "description": "Python is a versatile programming language used for web development, data analysis, artificial intelligence, and more.",
    "link": "https://www.python.org/",
    "winget": "Python.Python.3.14",
    "foss": true
  },
  "qbittorrent": {
    "category": "Utilities",
    "choco": "qbittorrent",
    "content": "qBittorrent",
    "description": "qBittorrent is a free and open-source BitTorrent client that aims to provide a feature-rich and lightweight alternative to other torrent clients.",
    "link": "https://www.qbittorrent.org/",
    "winget": "qBittorrent.qBittorrent",
    "foss": true
  },
  "qownnotes": {
    "category": "Document",
    "choco": "qownnotes",
    "content": "QOwnNotes",
    "description": "QOwnNotes is a free open-source note-taking app with Nextcloud/ownCloud integration.",
    "link": "https://www.qownnotes.org/",
    "winget": "pbek.QOwnNotes",
    "foss": true
  },
  "qtox": {
    "category": "Communications",
    "choco": "qtox",
    "content": "QTox",
    "description": "QTox is a free and open-source messaging app that prioritizes user privacy and security in its design.",
    "link": "https://qtox.github.io/",
    "winget": "Tox.qTox",
    "foss": true
  },
  "revo": {
    "category": "Utilities",
    "choco": "revo-uninstaller",
    "content": "Revo Uninstaller",
    "description": "Revo Uninstaller is an advanced uninstaller tool that helps you remove unwanted software and clean up your system.",
    "link": "https://www.revouninstaller.com/",
    "winget": "RevoUninstaller.RevoUninstaller",
    "foss": false
  },
  "WiseProgramUninstaller": {
    "category": "Utilities",
    "choco": "na",
    "content": "Wise Program Uninstaller (WiseCleaner)",
    "description": "Wise Program Uninstaller is the perfect solution for uninstalling Windows programs, allowing you to uninstall applications quickly and completely using its simple and user-friendly interface.",
    "link": "https://www.wisecleaner.com/wise-program-uninstaller.html",
    "winget": "WiseCleaner.WiseProgramUninstaller",
    "foss": false
  },
  "rufus": {
    "category": "Utilities",
    "choco": "rufus",
    "content": "Rufus Imager",
    "description": "Rufus is a utility that helps format and create bootable USB drives, such as USB keys or pen drives.",
    "link": "https://rufus.ie/",
    "winget": "Rufus.Rufus",
    "foss": true
  },
  "rustlang": {
    "category": "Development",
    "choco": "rust",
    "content": "Rust",
    "description": "Rust is a programming language designed for safety and performance, particularly focused on systems programming.",
    "link": "https://www.rust-lang.org/",
    "winget": "Rustlang.Rust.MSVC",
    "foss": true
  },
  "sdio": {
    "category": "Utilities",
    "choco": "sdio",
    "content": "Snappy Driver Installer Origin",
    "description": "Snappy Driver Installer Origin is a free and open-source driver updater with a vast driver database for Windows.",
    "link": "https://www.glenn.delahoy.com/snappy-driver-installer-origin/",
    "winget": "GlennDelahoy.SnappyDriverInstallerOrigin",
    "foss": true
  },
  "sharex": {
    "category": "Multimedia Tools",
    "choco": "sharex",
    "content": "ShareX (Screenshots)",
    "description": "ShareX is a free and open-source screen capture and file sharing tool. It supports various capture methods and offers advanced features for editing and sharing screenshots.",
    "link": "https://getsharex.com/",
    "winget": "ShareX.ShareX",
    "foss": true
  },
  "nilesoftShell": {
    "category": "Utilities",
    "choco": "nilesoft-shell",
    "content": "Nilesoft Shell",
    "description": "Shell is an expanded context menu tool that adds extra functionality and customization options to the Windows context menu.",
    "link": "https://nilesoft.org/",
    "winget": "Nilesoft.Shell",
    "foss": false
  },
  "systeminformer": {
    "category": "Development",
    "choco": "systeminformer",
    "content": "System Informer",
    "description": "A free, powerful, multi-purpose tool that helps you monitor system resources, debug software and detect malware.",
    "link": "https://systeminformer.com/",
    "winget": "WinsiderSS.SystemInformer",
    "foss": true
  },
  "signal": {
    "category": "Communications",
    "choco": "signal",
    "content": "Signal",
    "description": "Signal is a privacy-focused messaging app that offers end-to-end encryption for secure and private communication.",
    "link": "https://signal.org/",
    "winget": "OpenWhisperSystems.Signal",
    "foss": true
  },
  "signalrgb": {
    "category": "Utilities",
    "choco": "na",
    "content": "SignalRGB",
    "description": "SignalRGB lets you control and sync your favorite RGB devices with one free application.",
    "link": "https://www.signalrgb.com/",
    "winget": "WhirlwindFX.SignalRgb",
    "foss": false
  },
  "simplenote": {
    "category": "Document",
    "choco": "simplenote",
    "content": "Simplenote",
    "description": "Simplenote is an easy way to keep notes, lists, ideas and more.",
    "link": "https://simplenote.com/",
    "winget": "Automattic.Simplenote",
    "foss": true
  },
  "simplewall": {
    "category": "Pro Tools",
    "choco": "simplewall",
    "content": "Simplewall",
    "description": "Simplewall is a free and open-source firewall application for Windows. It allows users to control and manage the inbound and outbound network traffic of applications.",
    "link": "https://github.com/henrypp/simplewall",
    "winget": "Henry++.simplewall",
    "foss": true
  },
  "slack": {
    "category": "Communications",
    "choco": "slack",
    "content": "Slack",
    "description": "Slack is a collaboration hub that connects teams and facilitates communication through channels, messaging, and file sharing.",
    "link": "https://slack.com/",
    "winget": "SlackTechnologies.Slack",
    "foss": false
  },
  "startallback": {
    "category": "Utilities",
    "choco": "StartAllBack",
    "content": "StartAllBack",
    "description": "StartAllBack restores and improves Windows taskbar, Start menu, File Explorer, and shell UI behavior.",
    "link": "https://www.startallback.com/",
    "winget": "StartIsBack.StartAllBack",
    "foss": false
  },
  "starship": {
    "category": "Development",
    "choco": "starship",
    "content": "Starship (Shell Prompt)",
    "description": "Starship is a fast, customizable, cross-platform prompt for PowerShell and other shells.",
    "link": "https://starship.rs/",
    "winget": "Starship.Starship",
    "foss": true
  },
  "steam": {
    "category": "Games",
    "choco": "steam-client",
    "content": "Steam",
    "description": "Steam is a digital distribution platform for purchasing and playing video games, offering multiplayer gaming, video streaming, and more.",
    "link": "https://store.steampowered.com/about/",
    "winget": "Valve.Steam",
    "foss": false
  },
  "roblox": {
    "category": "Games",
    "choco": "na",
    "content": "Roblox",
    "description": "Roblox is a platform and game creation system that allows users to create and play games developed by the community.",
    "link": "https://www.roblox.com/",
    "winget": "Roblox.Roblox",
    "foss": false
  },
  "sublimetext": {
    "category": "Development",
    "choco": "sublimetext4",
    "content": "Sublime Text",
    "description": "Sublime Text is a sophisticated text editor for code, markup, and prose.",
    "link": "https://www.sublimetext.com/",
    "winget": "SublimeHQ.SublimeText.4",
    "foss": false
  },
  "sumatra": {
    "category": "Document",
    "choco": "sumatrapdf",
    "content": "Sumatra PDF",
    "description": "Sumatra PDF is a lightweight and fast PDF viewer with minimalistic design.",
    "link": "https://www.sumatrapdfreader.org/free-pdf-reader.html",
    "winget": "SumatraPDF.SumatraPDF",
    "foss": true
  },
  "sunshine": {
    "category": "Selfhosted Tools",
    "choco": "sunshine",
    "content": "Sunshine/GameStream Server",
    "description": "Sunshine is a GameStream server that allows you to remotely play PC games on Android devices, offering low-latency streaming.",
    "link": "https://app.lizardbyte.dev/Sunshine/",
    "winget": "LizardByte.Sunshine",
    "foss": true
  },
  "synctrayzor": {
    "category": "Selfhosted Tools",
    "choco": "synctrayzor",
    "content": "SyncTrayzor",
    "description": "SyncTrayzor is a Windows tray utility that bundles and wraps Syncthing, making it behave like a native application to easily manage and monitor file synchronization.",
    "link": "https://github.com/GermanCoding/SyncTrayzor",
    "winget": "GermanCoding.SyncTrayzor"
  },
  "syncthing": {
    "category": "Selfhosted Tools",
    "choco": "syncthing",
    "content": "Syncthing (CLI / Web UI)",
    "description": "Syncthing is a decentralized, peer-to-peer file synchronization tool that securely syncs files directly across devices without cloud servers, managed via a local web interface.",
    "link": "https://syncthing.net/",
    "winget": "Syncthing.Syncthing",
    "foss": true
  },
  "tcpview": {
    "category": "Microsoft Tools",
    "choco": "tcpview",
    "content": "TCPView",
    "description": "SysInternals TCPView is a network monitoring tool that displays a detailed list of all TCP and UDP endpoints on your system.",
    "link": "https://docs.microsoft.com/en-us/sysinternals/downloads/tcpview",
    "winget": "Microsoft.Sysinternals.TCPView",
    "foss": false
  },
  "teams": {
    "category": "Communications",
    "choco": "microsoft-teams",
    "content": "Teams",
    "description": "Microsoft Teams is a collaboration platform that integrates with Office 365 and offers chat, video conferencing, file sharing, and more.",
    "link": "https://www.microsoft.com/en-us/microsoft-teams/group-chat-software",
    "winget": "Microsoft.Teams",
    "foss": false
  },
  "teamviewer": {
    "category": "Utilities",
    "choco": "teamviewer9",
    "content": "TeamViewer",
    "description": "TeamViewer is a popular remote access and support software that allows you to connect to and control remote devices.",
    "link": "https://www.teamviewer.com/",
    "winget": "TeamViewer.TeamViewer",
    "foss": false
  },
  "teamspeak3": {
    "category": "Communications",
    "choco": "teamspeak",
    "content": "TeamSpeak 3",
    "description": "TEAMSPEAK. YOUR TEAM. YOUR RULES. Use crystal clear sound to communicate with your teammates cross-platform with military-grade security, lag-free performance & unparalleled reliability and uptime.",
    "link": "https://www.teamspeak.com/",
    "winget": "TeamSpeakSystems.TeamSpeakClient",
    "foss": false
  },
  "teamspeak6": {
    "category": "Communications",
    "choco": "na",
    "content": "TeamSpeak 6",
    "description": "TEAMSPEAK. YOUR TEAM. YOUR RULES. Use crystal clear sound to communicate with your teammates cross-platform with military-grade security, lag-free performance & unparalleled reliability and uptime.",
    "link": "https://www.teamspeak.com/",
    "winget": "TeamSpeakSystems.TeamSpeakClient.Beta.6",
    "foss": false
  },
  "telegram": {
    "category": "Communications",
    "choco": "telegram",
    "content": "Telegram",
    "description": "Telegram is a cloud-based instant messaging app known for its security features, speed, and simplicity.",
    "link": "https://telegram.org/",
    "winget": "Telegram.TelegramDesktop",
    "foss": true
  },
  "terminal": {
    "category": "Microsoft Tools",
    "choco": "microsoft-windows-terminal",
    "content": "Windows Terminal",
    "description": "Windows Terminal is a modern, fast, and efficient terminal application for command-line users, supporting multiple tabs, panes, and more.",
    "link": "https://aka.ms/terminal",
    "winget": "Microsoft.WindowsTerminal",
    "foss": true
  },
  "thunderbird": {
    "category": "Communications",
    "choco": "thunderbird",
    "content": "Thunderbird",
    "description": "Mozilla Thunderbird is a free and open-source email client, news client, and chat client with advanced features.",
    "link": "https://www.thunderbird.net/",
    "winget": "Mozilla.Thunderbird",
    "foss": true
  },
  "betterbird": {
    "category": "Communications",
    "choco": "betterbird",
    "content": "Betterbird",
    "description": "Betterbird is a fork of Mozilla Thunderbird with additional features and bugfixes.",
    "link": "https://www.betterbird.eu/",
    "winget": "Betterbird.Betterbird",
    "foss": true
  },
  "tor": {
    "category": "Browsers",
    "choco": "tor-browser",
    "content": "Tor Browser",
    "description": "Tor Browser is designed for anonymous web browsing, utilizing the Tor network to protect user privacy and security.",
    "link": "https://www.torproject.org/",
    "winget": "TorProject.TorBrowser",
    "foss": true
  },
  "totalcommander": {
    "category": "Utilities",
    "choco": "TotalCommander",
    "content": "Total Commander",
    "description": "Total Commander is a file manager for Windows that provides a powerful and intuitive interface for file management.",
    "link": "https://www.ghisler.com/",
    "winget": "Ghisler.TotalCommander",
    "foss": false
  },
  "treesize": {
    "category": "Utilities",
    "choco": "treesizefree",
    "content": "TreeSize Free",
    "description": "TreeSize Free is a disk space manager that helps you analyze and visualize the space usage on your drives.",
    "link": "https://www.jam-software.com/treesize_free/",
    "winget": "JAMSoftware.TreeSize.Free",
    "foss": false
  },
  "ttaskbar": {
    "category": "Utilities",
    "choco": "translucenttb",
    "content": "TranslucentTB",
    "description": "TranslucentTB is a tool that allows you to customize the transparency of the Windows Taskbar.",
    "link": "https://translucenttb.github.io",
    "winget": "CharlesMilette.TranslucentTB",
    "foss": true
  },
  "ubisoft": {
    "category": "Games",
    "choco": "ubisoft-connect",
    "content": "Ubisoft Connect",
    "description": "Ubisoft Connect is Ubisoft's digital distribution and online gaming service, providing access to Ubisoft's games and services.",
    "link": "https://ubisoftconnect.com/",
    "winget": "Ubisoft.Connect",
    "foss": false
  },
  "ungoogled": {
    "category": "Browsers",
    "choco": "ungoogled-chromium",
    "content": "Ungoogled Chromium",
    "description": "Ungoogled Chromium is a version of Chromium without Google's integration for enhanced privacy and control.",
    "link": "https://github.com/Eloston/ungoogled-chromium",
    "winget": "eloston.ungoogled-chromium",
    "foss": true
  },
  "unity": {
    "category": "Development",
    "choco": "unityhub",
    "content": "Unity Game Engine",
    "description": "Unity is a powerful game development platform for creating 2D, 3D, augmented reality, and virtual reality games.",
    "link": "https://unity.com/",
    "winget": "Unity.UnityHub",
    "foss": false
  },
  "vagrant": {
    "category": "Development",
    "choco": "vagrant",
    "content": "Vagrant",
    "description": "Vagrant builds and manages reproducible virtual machine development environments from declarative configuration.",
    "link": "https://developer.hashicorp.com/vagrant",
    "winget": "Hashicorp.Vagrant",
    "foss": false
  },
  "everything": {
    "category": "Utilities",
    "choco": "everything",
    "content": "Everything",
    "description": "Everything is a search engine that locates files and folders by filename instantly for Windows. Unlike Windows search Everything initially displays every file and folder on your computer (hence the name Everything). You type in a search filter to limit what files and folders are displayed.",
    "link": "https://www.voidtools.com/",
    "winget": "voidtools.Everything",
    "foss": false
  },
  "vc2015_32": {
    "category": "Microsoft Tools",
    "choco": "vcredist2015",
    "content": "Visual C++ 2015-2022 32-bit",
    "description": "Visual C++ 2015-2022 32-bit redistributable package installs runtime components of Visual C++ libraries required to run 32-bit applications.",
    "link": "https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads",
    "winget": "Microsoft.VCRedist.2015+.x86",
    "foss": false
  },
  "vc2015_64": {
    "category": "Microsoft Tools",
    "choco": "vcredist2015",
    "content": "Visual C++ 2015-2022 64-bit",
    "description": "Visual C++ 2015-2022 64-bit redistributable package installs runtime components of Visual C++ libraries required to run 64-bit applications.",
    "link": "https://support.microsoft.com/en-us/help/2977003/the-latest-supported-visual-c-downloads",
    "winget": "Microsoft.VCRedist.2015+.x64",
    "foss": false
  },
  "ventoy": {
    "category": "Pro Tools",
    "choco": "ventoy",
    "content": "Ventoy",
    "description": "Ventoy is an open-source tool for creating bootable USB drives. It supports multiple ISO files on a single USB drive, making it a versatile solution for installing operating systems.",
    "link": "https://www.ventoy.net/",
    "winget": "Ventoy.Ventoy",
    "foss": true
  },
  "vesktop": {
    "category": "Communications",
    "choco": "na",
    "content": "Vesktop",
    "description": "A cross-platform electron-based desktop app aiming to give you a snappier Discord experience with Vencord pre-installed.",
    "link": "https://vesktop.dev",
    "winget": "Vencord.Vesktop",
    "foss": true
  },
  "viber": {
    "category": "Communications",
    "choco": "viber",
    "content": "Viber",
    "description": "Viber is a free messaging and calling app with features like group chats, video calls, and more.",
    "link": "https://www.viber.com/",
    "winget": "Rakuten.Viber",
    "foss": false
  },
  "visualstudio2022": {
    "category": "Development",
    "choco": "visualstudio2022community",
    "content": "Visual Studio 2022",
    "description": "Visual Studio 2022 is an integrated development environment (IDE) for building, debugging, and deploying applications.",
    "link": "https://visualstudio.microsoft.com/",
    "winget": "Microsoft.VisualStudio.2022.Community",
    "foss": false
  },
  "visualstudio2026": {
    "category": "Development",
    "choco": "visualstudio2026community",
    "content": "Visual Studio 2026",
    "description": "Visual Studio 2026 is an integrated development environment (IDE) for building, debugging, and deploying applications.",
    "link": "https://visualstudio.microsoft.com/",
    "winget": "Microsoft.VisualStudio.Community",
    "foss": false
  },
  "vivaldi": {
    "category": "Browsers",
    "choco": "vivaldi",
    "content": "Vivaldi",
    "description": "Vivaldi is a highly customizable web browser with a focus on user personalization and productivity features.",
    "link": "https://vivaldi.com/",
    "winget": "Vivaldi.Vivaldi",
    "foss": false
  },
  "vlc": {
    "category": "Multimedia Tools",
    "choco": "vlc",
    "content": "VLC (Video Player)",
    "description": "VLC Media Player is a free and open-source multimedia player that supports a wide range of audio and video formats. It is known for its versatility and cross-platform compatibility.",
    "link": "https://www.videolan.org/vlc/",
    "winget": "VideoLAN.VLC",
    "foss": true
  },
  "vrdesktopstreamer": {
    "category": "Games",
    "choco": "na",
    "content": "Virtual Desktop Streamer",
    "description": "Virtual Desktop Streamer is a tool that allows you to stream your desktop screen to VR devices.",
    "link": "https://www.vrdesktop.net/",
    "winget": "VirtualDesktop.Streamer",
    "foss": false
  },
  "vscode": {
    "category": "Development",
    "choco": "vscode",
    "content": "VS Code",
    "description": "Visual Studio Code is a free, open-source code editor with support for multiple programming languages.",
    "link": "https://code.visualstudio.com/",
    "winget": "Microsoft.VisualStudioCode",
    "foss": true
  },
  "vscodium": {
    "category": "Development",
    "choco": "vscodium",
    "content": "VS Codium",
    "description": "VSCodium is a community-driven, freely-licensed binary distribution of Microsoft's VS Code.",
    "link": "https://vscodium.com/",
    "winget": "VSCodium.VSCodium",
    "foss": true
  },
  "waterfox": {
    "category": "Browsers",
    "choco": "waterfox",
    "content": "Waterfox",
    "description": "Waterfox is a fast, privacy-focused web browser based on Firefox, designed to preserve user choice and privacy.",
    "link": "https://www.waterfox.net/",
    "winget": "Waterfox.Waterfox",
    "foss": true
  },
  "whatsapp": {
    "category": "Communications",
    "choco": "na",
    "content": "WhatsApp Desktop",
    "description": "WhatsApp Desktop is the official Windows desktop messaging app from Meta, distributed through the Microsoft Store.",
    "link": "https://www.whatsapp.com/download",
    "winget": "msstore:9NKSQGP7F2NH",
    "foss": false
  },
  "wingetui": {
    "category": "Utilities",
    "choco": "wingetui",
    "content": "UniGetUI",
    "description": "UniGetUI is a GUI for WinGet, Chocolatey, and other Windows CLI package managers.",
    "link": "https://devolutions.net/unigetui/",
    "winget": "Devolutions.UniGetUI",
    "foss": true
  },
  "winrar": {
    "category": "Utilities",
    "choco": "winrar",
    "content": "WinRAR",
    "description": "WinRAR is a powerful archive manager that allows you to create, manage, and extract compressed files.",
    "link": "https://www.win-rar.com/",
    "winget": "RARLab.WinRAR",
    "foss": false
  },
  "winscp": {
    "category": "Pro Tools",
    "choco": "winscp",
    "content": "WinSCP",
    "description": "WinSCP is a popular open-source SFTP, FTP, and SCP client for Windows. It allows secure file transfers between a local and a remote computer.",
    "link": "https://winscp.net/",
    "winget": "WinSCP.WinSCP",
    "foss": true
  },
  "wireguard": {
    "category": "Pro Tools",
    "choco": "wireguard",
    "content": "WireGuard",
    "description": "WireGuard is a fast and modern VPN (Virtual Private Network) protocol. It aims to be simpler and more efficient than other VPN protocols, providing secure and reliable connections.",
    "link": "https://www.wireguard.com/",
    "winget": "WireGuard.WireGuard",
    "foss": true
  },
  "wireshark": {
    "category": "Pro Tools",
    "choco": "wireshark",
    "content": "Wireshark",
    "description": "Wireshark is a widely-used open-source network protocol analyzer. It allows users to capture and analyze network traffic in real-time, providing detailed insights into network activities.",
    "link": "https://www.wireshark.org/",
    "winget": "WiresharkFoundation.Wireshark",
    "foss": true
  },
  "wiztree": {
    "category": "Utilities",
    "choco": "wiztree",
    "content": "WizTree",
    "description": "WizTree is a fast disk space analyzer that helps you quickly find the files and folders consuming the most space on your hard drive.",
    "link": "https://wiztreefree.com/",
    "winget": "AntibodySoftware.WizTree",
    "foss": false
  },
  "xeheditor": {
    "category": "Utilities",
    "choco": "HxD",
    "content": "HxD Hex Editor",
    "description": "HxD is a free hex editor that allows you to edit, view, search, and analyze binary files.",
    "link": "https://mh-nexus.de/en/hxd/",
    "winget": "MHNexus.HxD",
    "foss": false
  },
  "xournal": {
    "category": "Document",
    "choco": "xournalplusplus",
    "content": "Xournal++",
    "description": "Xournal++ is an open-source handwriting notetaking software with PDF annotation capabilities.",
    "link": "https://xournalpp.github.io/",
    "winget": "Xournal++.Xournal++",
    "foss": true
  },
  "yarn": {
    "category": "Development",
    "choco": "yarn",
    "content": "Yarn",
    "description": "Yarn is a fast, reliable, and secure dependency management tool for JavaScript projects.",
    "link": "https://yarnpkg.com/",
    "winget": "Yarn.Yarn",
    "foss": true
  },
  "zoom": {
    "category": "Communications",
    "choco": "zoom",
    "content": "Zoom",
    "description": "Zoom is a popular video conferencing and web conferencing service for online meetings, webinars, and collaborative projects.",
    "link": "https://zoom.us/",
    "winget": "Zoom.Zoom",
    "foss": false
  },
  "uv": {
    "category": "Development",
    "choco": "uv",
    "content": "uv",
    "description": "uv is a fast Python package and project manager written in Rust.",
    "link": "https://docs.astral.sh/uv/getting-started/installation/",
    "winget": "astral-sh.uv",
    "foss": true
  },
  "tightvnc": {
    "category": "Utilities",
    "choco": "TightVNC",
    "content": "TightVNC",
    "description": "TightVNC is a free and open-source remote desktop software that lets you access and control a computer over the network. With its intuitive interface, you can interact with the remote screen as if you were sitting in front of it. You can open files, launch applications, and perform other actions on the remote desktop almost as if you were physically there.",
    "link": "https://www.tightvnc.com/",
    "winget": "GlavSoft.TightVNC",
    "foss": true
  },
  "glazewm": {
    "category": "Utilities",
    "choco": "glazewm",
    "content": "GlazeWM",
    "description": "GlazeWM is a tiling window manager for Windows inspired by i3 and Polybar.",
    "link": "https://github.com/glzr-io/glazewm",
    "winget": "glzr-io.glazewm",
    "foss": true
  },
  "Overwolf": {
    "category": "Games",
    "content": "CurseForge",
    "description": "CurseForge is a desktop application for managing mods and modpacks across multiple games, powered by Overwolf.",
    "link": "https://www.overwolf.com/app/overwolf-curseforge",
    "winget": "Overwolf.CurseForge",
    "foss": false
  },
  "OFGB": {
    "category": "Utilities",
    "choco": "ofgb",
    "content": "OFGB (Oh Frick Go Back)",
    "description": "GUI Tool to remove ads from various places around Windows 11",
    "link": "https://github.com/xM4ddy/OFGB",
    "winget": "xM4ddy.OFGB",
    "foss": true
  },
  "ZenBrowser": {
    "category": "Browsers",
    "choco": "zen-browser",
    "content": "Zen Browser",
    "description": "The modern, privacy-focused, performance-driven browser built on Firefox.",
    "link": "https://zen-browser.app/",
    "winget": "Zen-Team.Zen-Browser",
    "foss": true
  },
  "Zed": {
    "category": "Development",
    "choco": "zed",
    "content": "Zed",
    "description": "Zed is a modern, high-performance code editor designed from the ground up for speed and collaboration.",
    "link": "https://zed.dev/",
    "winget": "ZedIndustries.Zed",
    "foss": true
  },
  "zotero": {
    "category": "Document",
    "choco": "zotero",
    "content": "Zotero",
    "description": "Zotero is a free, easy-to-use tool to help you collect, organize, cite, and share your research materials.",
    "link": "https://www.zotero.org/",
    "winget": "DigitalScholar.Zotero",
    "foss": true
  },
  "deskflow": {
    "category": "Utilities",
    "choco": "deskflow",
    "content": "Deskflow",
    "description": "Deskflow is a free and open-source software KVM that lets you share a single keyboard and mouse across multiple computers.",
    "link": "https://github.com/deskflow/deskflow",
    "winget": "Deskflow.Deskflow",
    "foss": true
  },
  "Ruby": {
    "category": "Development",
    "choco": "ruby",
    "winget": "RubyInstallerTeam.Ruby.4.0",
    "description": "A Ruby language execution environment with a MSYS2 installation.",
    "content": "Ruby",
    "link": "https://rubyinstaller.org/",
    "foss": true
  },
  "Lua": {
    "category": "Development",
    "choco": "lua",
    "winget": "rjpcomputing.luaforwindows",
    "description": "A 'batteries included environment' for the Lua scripting language on Windows.",
    "content": "Lua",
    "link": "https://github.com/rjpcomputing/luaforwindows",
    "foss": true
  },
  "CloudflareWARP": {
    "category": "Utilities",
    "choco": "warp",
    "winget": "Cloudflare.Warp",
    "description": "WARP is a freemium VPN service provided by Cloudflare. Includes usage of Cloudflare's DNS",
    "content": "Cloudflare WARP",
    "link": "https://one.one.one.one",
    "foss": false
  }
}
'@ | ConvertFrom-Json
$sync.configs.appnavigation = @'
{
  "WPFInstall": {
    "Content": "Install/Upgrade Applications",
    "Category": "____Actions",
    "Type": "Button",
    "Order": "1",
    "Description": "Install or upgrade the selected applications"
  },
  "WPFUninstall": {
    "Content": "Uninstall Applications",
    "Category": "____Actions",
    "Type": "Button",
    "Order": "2",
    "Description": "Uninstall the selected applications"
  },
  "WPFInstallUpgrade": {
    "Content": "Upgrade all Applications",
    "Category": "____Actions",
    "Type": "Button",
    "Order": "3",
    "Description": "Upgrade all applications to the latest version"
  },
  "WingetRadioButton": {
    "Content": "WinGet",
    "Category": "__Package Manager",
    "Type": "RadioButton",
    "GroupName": "PackageManagerGroup",
    "Checked": true,
    "Order": "1",
    "Description": "Use WinGet for package management"
  },
  "ChocoRadioButton": {
    "Content": "Chocolatey",
    "Category": "__Package Manager",
    "Type": "RadioButton",
    "GroupName": "PackageManagerGroup",
    "Checked": false,
    "Order": "2",
    "Description": "Use Chocolatey for package management"
  },
  "WPFCollapseAllCategories": {
    "Content": "Collapse All Categories",
    "Category": "__Selection",
    "Type": "Button",
    "Order": "1",
    "Description": "Collapse all application categories"
  },
  "WPFExpandAllCategories": {
    "Content": "Expand All Categories",
    "Category": "__Selection",
    "Type": "Button",
    "Order": "2",
    "Description": "Expand all application categories"
  },
  "WPFClearInstallSelection": {
    "Content": "Clear Selection",
    "Category": "__Selection",
    "Type": "Button",
    "Order": "3",
    "Description": "Clear the selection of applications"
  },
  "WPFGetInstalled": {
    "Content": "Show Installed Apps",
    "Category": "__Selection",
    "Type": "Button",
    "Order": "4",
    "Description": "Show installed applications"
  },
  "WPFselectedAppsButton": {
    "Content": "Selected Apps: 0",
    "Category": "__Selection",
    "Type": "Button",
    "Order": "5",
    "Description": "Show the selected applications"
  },
  "WPFInstallFOSSInfo": {
    "Content": "Free and Open Source Software",
    "Category": "__Selection",
    "Type": "Note",
    "Order": "0",
    "Description": "Information about the #FOSS label on application entries"
  }
}
'@ | ConvertFrom-Json
$sync.configs.appx = @'
{
  "WPFAppxMicrosoft_WindowsFeedbackHub": {
    "Category": "Microsoft Apps",
    "Content": "Feedback Hub",
    "Description": "Allows users to submit bug reports, feature suggestions, and diagnostic data directly to Microsoft.",
    "Panel": "0",
    "PackageId": "Microsoft.WindowsFeedbackHub",
    "StoreId": "9NBLGGH4R32N"
  },
  "WPFAppxMicrosoft_GetHelp": {
    "Category": "Microsoft Apps",
    "Content": "Get Help",
    "Description": "Provides access to automated troubleshooting guides, support documentation, and direct Microsoft customer assistance.",
    "Panel": "0",
    "PackageId": "Microsoft.GetHelp",
    "StoreId": "9PKDZBMV1H3T"
  },
  "WPFAppxMicrosoft_OutlookForWindows": {
    "Category": "Microsoft Apps",
    "Content": "Outlook for Windows",
    "Description": "Provides modern email management, calendar scheduling, and contact organization features.",
    "Panel": "0",
    "PackageId": "Microsoft.OutlookForWindows",
    "StoreId": "9NRX63209R7B"
  },
  "WPFAppxMSTeams": {
    "Category": "Microsoft Apps",
    "Content": "Microsoft Teams",
    "Description": "Facilitates instant messaging, video conferencing, file sharing, and workspace collaboration.",
    "Panel": "0",
    "PackageId": "MSTeams",
    "StoreId": "XP8BT8DW290MPQ"
  },
  "WPFAppxClipchamp_Clipchamp": {
    "Category": "Utilities & Productivity",
    "Content": "Clipchamp",
    "Description": "Provides a user-friendly video editor with built-in templates, effects, and timeline editing tools.",
    "Panel": "0",
    "PackageId": "Clipchamp.Clipchamp",
    "StoreId": "9P1J8S7CCWWT"
  },
  "WPFAppxMicrosoft_MicrosoftOfficeHub": {
    "Category": "Microsoft Apps",
    "Content": "Microsoft 365",
    "Description": "Serves as a centralized launcher and dashboard for accessing cloud-based Microsoft 365 apps and recent documents.",
    "Panel": "0",
    "PackageId": "Microsoft.MicrosoftOfficeHub",
    "StoreId": "9WZDNCRD29V9"
  },
  "WPFAppxMicrosoft_ZuneMusic": {
    "Category": "Utilities & Productivity",
    "Content": "Media Player",
    "Description": "Plays local audio and video files with modern playlist management and casting capabilities.",
    "Panel": "0",
    "PackageId": "Microsoft.ZuneMusic",
    "StoreId": "9WZDNCRFJ3PT"
  },
  "WPFAppxMicrosoft_BingSearch": {
    "Category": "Bing & Web Services",
    "Content": "Bing Search",
    "Description": "Integrates Microsoft Bing search capabilities and web services directly into the operating system.",
    "Panel": "1",
    "PackageId": "Microsoft.BingSearch",
    "StoreId": "9NZBF4GT040C"
  },
  "WPFAppxMicrosoftCorporationII_QuickAssist": {
    "Category": "Utilities & Productivity",
    "Content": "Quick Assist",
    "Description": "Enables secure remote technical support and screen sharing over an internet connection.",
    "Panel": "0",
    "PackageId": "MicrosoftCorporationII.QuickAssist",
    "StoreId": "9P7BP5VNWKX5"
  },
  "WPFAppxMicrosoft_WindowsDevHome": {
    "Category": "Developer Tools",
    "Content": "Dev Home",
    "Description": "Provides a specialized dashboard for software developer environment setups, repository syncing, and hardware widgets.",
    "Panel": "1",
    "PackageId": "Microsoft.Windows.DevHome",
    "StoreId": "9N8MHTPHNGVV"
  },
  "WPFAppxMicrosoft_WindowsCrossDevice": {
    "Category": "Microsoft Ecosystem",
    "Content": "Mobile Devices",
    "Description": "Manages system-level background connectivity with paired mobile devices. Removing this may disable cross-device features such as phone screen mirroring, file transfer, and mobile hotspot handoff integrated into Windows Settings.",
    "Panel": "0",
    "PackageId": "MicrosoftWindows.CrossDevice",
    "StoreId": "9NTXGKQ8P7N0"
  },
  "WPFAppxMicrosoft_Todos": {
    "Category": "Utilities & Productivity",
    "Content": "To Do",
    "Description": "Creates, tracks, and synchronizes personal tasks, smart lists, and daily reminders.",
    "Panel": "0",
    "PackageId": "Microsoft.Todos",
    "StoreId": "9NBLGGH5R558"
  },
  "WPFAppxMicrosoft_PowerAutomateDesktop": {
    "Category": "Developer Tools",
    "Content": "Power Automate",
    "Description": "Automates repetitive workflows and desktop tasks using low-code visual scripting.",
    "Panel": "1",
    "PackageId": "Microsoft.PowerAutomateDesktop",
    "StoreId": "9NFTCH6J7FHV"
  },
  "WPFAppxMicrosoft_YourPhone": {
    "Category": "Microsoft Ecosystem",
    "Content": "Phone Link",
    "Description": "Synchronizes text messages, phone notifications, photos, and calls from a mobile device to the desktop.",
    "Panel": "0",
    "PackageId": "Microsoft.YourPhone",
    "StoreId": "9NMPJ99VJBWV"
  },
  "WPFAppxMicrosoft_MicrosoftStickyNotes": {
    "Category": "Utilities & Productivity",
    "Content": "Sticky Notes",
    "Description": "Creates quick, floating text notes on the desktop that automatically sync across devices.",
    "Panel": "0",
    "PackageId": "Microsoft.MicrosoftStickyNotes",
    "StoreId": "9NBLGGH4QGHW"
  },
  "WPFAppxMicrosoft_WindowsSoundRecorder": {
    "Category": "Utilities & Productivity",
    "Content": "Sound Recorder",
    "Description": "Records and trims live audio inputs with simple microphone adjustment controls.",
    "Panel": "0",
    "PackageId": "Microsoft.WindowsSoundRecorder",
    "StoreId": "9WZDNCRFHWKN"
  },
  "WPFAppxMicrosoft_WindowsAlarms": {
    "Category": "Utilities & Productivity",
    "Content": "Clock",
    "Description": "Features world clocks, alarms, countdown timers, stopwatches, and dedicated focus session tracking.",
    "Panel": "0",
    "PackageId": "Microsoft.WindowsAlarms",
    "StoreId": "9WZDNCRFJ3PR"
  },
  "WPFAppxMicrosoft_Paint": {
    "Category": "Utilities & Productivity",
    "Content": "Paint",
    "Description": "Provides built-in digital sketching, basic image editing, and pixel-level graphic manipulation tools.",
    "Panel": "0",
    "PackageId": "Microsoft.Paint",
    "StoreId": "9PCFS5B6T72H"
  },
  "WPFAppxMicrosoft_WindowsNotepad": {
    "Category": "Utilities & Productivity",
    "Content": "Notepad",
    "Description": "Provides a lightweight text editor with multi-tab support for plain text files and code snippets.",
    "Panel": "0",
    "PackageId": "Microsoft.WindowsNotepad",
    "StoreId": "9MSMLRH6LZF3"
  },
  "WPFAppxMicrosoft_ScreenSketch": {
    "Category": "Utilities & Productivity",
    "Content": "Snipping Tool",
    "Description": "Captures screenshots or screen recordings with built-in markup, image cropping, and optical character recognition (OCR).",
    "Panel": "0",
    "PackageId": "Microsoft.ScreenSketch",
    "StoreId": "9MZ95KL8MR0L"
  },
  "WPFAppxMicrosoft_Copilot": {
    "Category": "Bing & Web Services",
    "Content": "Copilot",
    "Description": "Launches the Microsoft AI companion for contextual answers, creative writing assistance, and intelligent web search.",
    "Panel": "1",
    "PackageId": "Microsoft.Copilot",
    "StoreId": "9NHT9RB2F4HD"
  },
  "WPFAppxMicrosoft_WindowsCalculator": {
    "Category": "Utilities & Productivity",
    "Content": "Calculator",
    "Description": "Performs standard arithmetic, scientific operations, programming calculations, and unit conversions.",
    "Panel": "0",
    "PackageId": "Microsoft.WindowsCalculator",
    "StoreId": "9WZDNCRFHVN5"
  },
  "WPFAppxMicrosoft_WindowsCamera": {
    "Category": "Utilities & Productivity",
    "Content": "Camera",
    "Description": "Captures photographs and records video files via connected webcams or imaging hardware.",
    "Panel": "0",
    "PackageId": "Microsoft.WindowsCamera",
    "StoreId": "9WZDNCRFJBBG"
  },
  "WPFAppxMicrosoft_WindowsPhotos": {
    "Category": "Utilities & Productivity",
    "Content": "Photos",
    "Description": "Organizes, views, and crops local images with basic color adjustment and album creation tools.",
    "Panel": "0",
    "PackageId": "Microsoft.Windows.Photos",
    "StoreId": "9WZDNCRFJBH4"
  },
  "WPFAppxMicrosoft_BingNews": {
    "Category": "Bing & Web Services",
    "Content": "News",
    "Description": "Aggregates breaking news headlines, personalized article feeds, and world current events.",
    "Panel": "1",
    "PackageId": "Microsoft.BingNews",
    "StoreId": "9WZDNCRFHVFW"
  },
  "WPFAppxMicrosoft_BingWeather": {
    "Category": "Bing & Web Services",
    "Content": "Weather",
    "Description": "Displays local real-time weather tracking, radar maps, and historical meteorological forecasts.",
    "Panel": "1",
    "PackageId": "Microsoft.BingWeather",
    "StoreId": "9WZDNCRFJ3Q2"
  },
  "WPFAppxMicrosoft_GamingApp": {
    "Category": "Xbox & Gaming",
    "Content": "Xbox App",
    "Description": "Serves as the primary gaming library manager, social community interface, and PC Game Pass dashboard.",
    "Panel": "1",
    "PackageId": "Microsoft.GamingApp",
    "StoreId": "9MV0B5HZVK9Z"
  },
  "WPFAppxMicrosoft_XboxGamingOverlay": {
    "Category": "Xbox & Gaming",
    "Content": "Xbox Game Bar",
    "Description": "Provides customizable in-game status widgets, audio balancing sliders, system monitoring tools, and gameplay recording.",
    "Panel": "1",
    "PackageId": "Microsoft.XboxGamingOverlay",
    "StoreId": "9NZKPSTSNW4P"
  },
  "WPFAppxMicrosoft_XboxIdentityProvider": {
    "Category": "Xbox & Gaming",
    "Content": "Xbox Identity Provider",
    "Description": "Manages Xbox network user authentication and background account validation for connected titles. Warning: removing this may break Microsoft account sign-in for non-Xbox games and apps that rely on this authentication pipeline.",
    "Panel": "1",
    "PackageId": "Microsoft.XboxIdentityProvider",
    "StoreId": "9WZDNCRD1HKW"
  },
  "WPFAppxMicrosoft_XboxSpeechToTextOverlay": {
    "Category": "Xbox & Gaming",
    "Content": "Xbox Speech To Text Overlay",
    "Description": "Provides system-level live accessibility captions and voice-to-text translation for gaming chat networks.",
    "Panel": "1",
    "PackageId": "Microsoft.XboxSpeechToTextOverlay"
  },
  "WPFAppxMicrosoft_Xbox_TCUI": {
    "Category": "Xbox & Gaming",
    "Content": "Xbox TCUI",
    "Description": "Provides core account connection UI modules for single sign-on flows within game titles. Warning: removing this may break Microsoft account authentication in games and apps that do not otherwise require the Xbox app.",
    "Panel": "1",
    "PackageId": "Microsoft.Xbox.TCUI"
  },
  "WPFAppxMicrosoft_StartExperiencesApp": {
    "Category": "Bing & Web Services",
    "Content": "Start Experiences App",
    "Description": "Powers the Windows Widgets board, delivering a personalized feed of news, weather, sports, and finance content.",
    "Panel": "1",
    "PackageId": "Microsoft.StartExperiencesApp",
    "StoreId": "9PC1H9VN18CM"
  },
  "WPFAppxMicrosoft_MicrosoftSolitaireCollection": {
    "Category": "Xbox & Gaming",
    "Content": "Solitaire Collection",
    "Description": "Bundles built-in card game modes including Klondike, Spider, FreeCell, Pyramid, and TriPeaks alongside daily challenges.",
    "Panel": "1",
    "PackageId": "Microsoft.MicrosoftSolitaireCollection"
  },
  "WPFAppxMicrosoft_ZuneVideo": {
    "Category": "Utilities & Productivity",
    "Content": "Movies & TV",
    "Description": "The default video player and storefront for purchasing or renting media.",
    "Panel": "0",
    "PackageId": "Microsoft.ZuneVideo",
    "StoreId": "9WZDNCRFJ3P2"
  }
}
'@ | ConvertFrom-Json
$sync.configs.dns = @'
{
  "Google": {
    "BenchmarkEligible": true,
    "Primary": "8.8.8.8",
    "Secondary": "8.8.4.4",
    "Primary6": "2001:4860:4860::8888",
    "Secondary6": "2001:4860:4860::8844",
    "DohTemplate": "https://dns.google/dns-query"
  },
  "Cloudflare": {
    "BenchmarkEligible": true,
    "Primary": "1.1.1.1",
    "Secondary": "1.0.0.1",
    "Primary6": "2606:4700:4700::1111",
    "Secondary6": "2606:4700:4700::1001",
    "DohTemplate": "https://cloudflare-dns.com/dns-query"
  },
  "Cloudflare_Malware": {
    "Primary": "1.1.1.2",
    "Secondary": "1.0.0.2",
    "Primary6": "2606:4700:4700::1112",
    "Secondary6": "2606:4700:4700::1002",
    "DohTemplate": "https://security.cloudflare-dns.com/dns-query"
  },
  "Cloudflare_Malware_Adult": {
    "Primary": "1.1.1.3",
    "Secondary": "1.0.0.3",
    "Primary6": "2606:4700:4700::1113",
    "Secondary6": "2606:4700:4700::1003",
    "DohTemplate": "https://family.cloudflare-dns.com/dns-query"
  },
  "Open_DNS": {
    "Primary": "208.67.222.222",
    "Secondary": "208.67.220.220",
    "Primary6": "2620:119:35::35",
    "Secondary6": "2620:119:53::53",
    "DohTemplate": "https://doh.opendns.com/dns-query"
  },
  "Quad9": {
    "Primary": "9.9.9.9",
    "Secondary": "149.112.112.112",
    "Primary6": "2620:fe::fe",
    "Secondary6": "2620:fe::9",
    "DohTemplate": "https://dns.quad9.net/dns-query"
  },
  "AdGuard_Ads_Trackers": {
    "Primary": "94.140.14.14",
    "Secondary": "94.140.15.15",
    "Primary6": "2a10:50c0::ad1:ff",
    "Secondary6": "2a10:50c0::ad2:ff",
    "DohTemplate": "https://dns.adguard-dns.com/dns-query"
  },
  "AdGuard_Ads_Trackers_Malware_Adult": {
    "Primary": "94.140.14.15",
    "Secondary": "94.140.15.16",
    "Primary6": "2a10:50c0::bad1:ff",
    "Secondary6": "2a10:50c0::bad2:ff",
    "DohTemplate": "https://family.adguard-dns.com/dns-query"
  }
}
'@ | ConvertFrom-Json
$sync.configs.feature = @'
{
  "WPFFeaturesdotnet": {
    "Content": ".NET Framework (Versions 2, 3, 4) - Enable",
    "Description": ".NET and .NET Framework is a developer platform made up of tools, programming languages, and libraries for building many different types of applications.",
    "category": "Features",
    "panel": "1",
    "feature": [
      "NetFx4-AdvSrvs",
      "NetFx3"
    ],
    "InvokeScript": [],
    "link": "https://winutil.christitus.com/code-reference/features/features/dotnet"
  },
  "WPFFixesNTPPool": {
    "Content": "NTP Server - Enable",
    "Description": "Replaces the default Windows NTP server (time.windows.com) with pool.ntp.org for improved time synchronization accuracy and reliability.",
    "category": "Fixes",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFixesNTPPool",
    "link": "https://winutil.christitus.com/code-reference/features/fixes/ntppool"
  },
  "WPFFeatureshyperv": {
    "Content": "Hyper-V - Enable",
    "Description": "Hyper-V is a hardware virtualization product developed by Microsoft that allows users to create and manage virtual machines.",
    "category": "Features",
    "panel": "1",
    "feature": [
      "Microsoft-Hyper-V-All"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/features/hyperv"
  },
  "WPFFeatureslegacymedia": {
    "Content": "Legacy Media Components (WMP, DirectPlay) - Enable",
    "Description": "Enables legacy programs from previous versions of Windows.",
    "category": "Features",
    "panel": "1",
    "feature": [
      "WindowsMediaPlayer",
      "MediaPlayback",
      "DirectPlay",
      "LegacyComponents"
    ],
    "InvokeScript": [],
    "link": "https://winutil.christitus.com/code-reference/features/features/legacymedia"
  },
  "WPFFeaturewsl": {
    "Content": "Windows Subsystem for Linux (WSL) - Enable",
    "Description": "Windows Subsystem for Linux is an optional feature of Windows that allows Linux programs to run natively on Windows without the need for a separate virtual machine or dual booting.",
    "category": "Features",
    "panel": "1",
    "feature": [
      "VirtualMachinePlatform",
      "Microsoft-Windows-Subsystem-Linux"
    ],
    "InvokeScript": [],
    "link": "https://winutil.christitus.com/code-reference/features/features/wsl"
  },
  "WPFFeaturenfs": {
    "Content": "Network File System (NFS) - Enable",
    "Description": "Network File System (NFS) is a mechanism for storing files on a network.",
    "category": "Features",
    "panel": "1",
    "feature": [
      "ServicesForNFS-ClientOnly",
      "ClientForNFS-Infrastructure",
      "NFS-Administration"
    ],
    "InvokeScript": [
      "nfsadmin client stop",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default' -Name 'AnonymousUID' -Type DWord -Value 0",
      "Set-ItemProperty -Path 'HKLM:\\SOFTWARE\\Microsoft\\ClientForNFS\\CurrentVersion\\Default' -Name 'AnonymousGID' -Type DWord -Value 0",
      "nfsadmin client start",
      "nfsadmin client localhost config fileaccess=755 SecFlavors=+sys -krb5 -krb5i"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/features/nfs"
  },
  "WPFFeatureRegBackup": {
    "Content": "Registry Backup (Daily Task 12:30am) - Enable",
    "Description": "Enables daily registry backup, previously disabled by Microsoft in Windows 10 1803.",
    "category": "Features",
    "panel": "1",
    "feature": [],
    "InvokeScript": [
      "\r\n      New-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Configuration Manager' -Name 'EnablePeriodicBackup' -Type DWord -Value 1 -Force\r\n      New-ItemProperty -Path 'HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager\\Configuration Manager' -Name 'BackupCount' -Type DWord -Value 2 -Force\r\n      $action = New-ScheduledTaskAction -Execute 'schtasks' -Argument '/run /i /tn \"\\Microsoft\\Windows\\Registry\\RegIdleBackup\"'\r\n      $trigger = New-ScheduledTaskTrigger -Daily -At 00:30\r\n      Register-ScheduledTask -Action $action -Trigger $trigger -TaskName 'AutoRegBackup' -Description 'Create System Registry Backups' -User 'System'\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/features/features/regbackup"
  },
  "WPFFeatureEnableLegacyRecovery": {
    "Content": "Legacy F8 Boot Recovery - Enable",
    "Description": "Enables Advanced Boot Options screen that lets you start Windows in advanced troubleshooting modes.",
    "category": "Features",
    "panel": "1",
    "feature": [],
    "InvokeScript": [
      "bcdedit /set bootmenupolicy legacy"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/features/enablelegacyrecovery"
  },
  "WPFFeatureDisableLegacyRecovery": {
    "Content": "Legacy F8 Boot Recovery - Disable",
    "Description": "Disables Advanced Boot Options screen that lets you start Windows in advanced troubleshooting modes.",
    "category": "Features",
    "panel": "1",
    "feature": [],
    "InvokeScript": [
      "bcdedit /set bootmenupolicy standard"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/features/disablelegacyrecovery"
  },
  "WPFFeaturesSandbox": {
    "Content": "Windows Sandbox - Enable",
    "Description": "Windows Sandbox is a lightweight virtual machine that provides a temporary desktop environment to safely run applications and programs in isolation.",
    "category": "Features",
    "panel": "1",
    "feature": [
      "Containers-DisposableClientVM"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/features/sandbox"
  },
  "WPFFeatureInstall": {
    "Content": "Install Features",
    "category": "Features",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFeatureInstall",
    "link": "https://winutil.christitus.com/code-reference/features/features/install"
  },
  "WPFPanelAutologin": {
    "Content": "AutoLogon - Run",
    "category": "Fixes",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFPanelAutologin",
    "link": "https://winutil.christitus.com/code-reference/features/fixes/autologin"
  },
  "WPFFixesUpdate": {
    "Content": "Windows Update - Reset",
    "category": "Fixes",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFixesUpdate",
    "link": "https://winutil.christitus.com/code-reference/features/fixes/update"
  },
  "WPFFixesNetwork": {
    "Content": "Network - Reset",
    "category": "Fixes",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFixesNetwork",
    "link": "https://winutil.christitus.com/code-reference/features/fixes/network"
  },
  "WPFPanelDISM": {
    "Content": "System Corruption Scan - Run",
    "category": "Fixes",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFSystemRepair",
    "link": "https://winutil.christitus.com/code-reference/features/fixes/dism"
  },
  "WPFFixesWinget": {
    "Content": "WinGet - Reinstall",
    "category": "Fixes",
    "panel": "1",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFFixesWinget",
    "link": "https://winutil.christitus.com/code-reference/features/fixes/winget"
  },
  "WPFPanelComputer": {
    "Content": "Computer Management",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "compmgmt.msc"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/computer"
  },
  "WPFPanelControl": {
    "Content": "Control Panel",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "control"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/control"
  },
  "WPFPanelMouse": {
    "Content": "Mouse Properties",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "main.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/mouse"
  },
  "WPFPanelNetwork": {
    "Content": "Network Connections",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "ncpa.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/network"
  },
  "WPFPanelPower": {
    "Content": "Power Panel",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "powercfg.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/power"
  },
  "WPFPanelPrinter": {
    "Content": "Printer Panel",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "Start-Process 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}'"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/printer"
  },
  "WPFPanelPrograms": {
    "Content": "Programs and Features",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "appwiz.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/programs"
  },
  "WPFPanelRegion": {
    "Content": "Region",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "intl.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/region"
  },
  "WPFPanelSecurity": {
    "Content": "Security and Maintenance",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "wscui.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/security"
  },
  "WPFPanelSound": {
    "Content": "Sound Settings",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "mmsys.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/sound"
  },
  "WPFPanelSystem": {
    "Content": "System Properties",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "sysdm.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/system"
  },
  "WPFPanelTimedate": {
    "Content": "Time and Date",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "timedate.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/timedate"
  },
  "WPFPanelFirewall": {
    "Content": "Windows Defender Firewall",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "firewall.cpl"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/firewall"
  },
  "WPFPanelRestore": {
    "Content": "Windows Restore",
    "category": "Legacy Windows Panels",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "InvokeScript": [
      "rstrui.exe"
    ],
    "link": "https://winutil.christitus.com/code-reference/features/legacy-windows-panels/restore"
  },
  "WPFtauredInstallPSProfile": {
    "Content": "CTT PowerShell Profile - Install",
    "category": "Powershell Profile Powershell 7+ Only",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-tauredInstallPSProfile",
    "link": "https://winutil.christitus.com/code-reference/features/powershell-profile-powershell-7--only/installpsprofile"
  },
  "WPFtauredUninstallPSProfile": {
    "Content": "CTT PowerShell Profile - Remove",
    "category": "Powershell Profile Powershell 7+ Only",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-tauredUninstallPSProfile",
    "link": "https://winutil.christitus.com/code-reference/features/powershell-profile-powershell-7--only/uninstallpsprofile"
  },
  "WPFtauredSSHServer": {
    "Content": "OpenSSH Server - Enable",
    "category": "Remote Access",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "function": "Invoke-WPFSSHServer",
    "link": "https://winutil.christitus.com/code-reference/features/remote-access/sshserver"
  }
}
'@ | ConvertFrom-Json
$sync.configs.preset = @'
{
  "Standard": [
    "WPFTweaksActivity",
    "WPFTweaksConsumerFeatures",
    "WPFTweaksDisableExplorerAutoDiscovery",
    "WPFTweaksWPBT",
    "WPFTweaksLocation",
    "WPFTweaksServices",
    "WPFTweaksTelemetry",
    "WPFTweaksDeliveryOptimization",
    "WPFTweaksDiskCleanup",
    "WPFTweaksDeleteTempFiles",
    "WPFTweaksEndTaskOnTaskbar",
    "WPFTweaksRestorePoint"
  ],
  "Minimal": [
    "WPFTweaksConsumerFeatures",
    "WPFTweaksWPBT",
    "WPFTweaksServices",
    "WPFTweaksTelemetry"
  ],
  "Advanced": [
    "WPFTweaksRestorePoint",
    "WPFTweaksActivity",
    "WPFTweaksConsumerFeatures",
    "WPFTweaksDisableExplorerAutoDiscovery",
    "WPFTweaksWPBT",
    "WPFTweaksLocation",
    "WPFTweaksServices",
    "WPFTweaksTelemetry",
    "WPFTweaksDeliveryOptimization",
    "WPFTweaksDeleteTempFiles",
    "WPFTweaksEndTaskOnTaskbar",
    "WPFTweaksDisableStoreSearch",
    "WPFTweaksRevertStartMenu",
    "WPFTweaksWidget",
    "WPFTweaksRemoveOneDrive",
    "WPFTweaksWindowsAI",
    "WPFTweaksRightClickMenu"
  ],
  "AppxDefault": [
    "WPFAppxMicrosoft_WindowsFeedbackHub",
    "WPFAppxMicrosoft_GetHelp",
    "WPFAppxMicrosoft_MicrosoftOfficeHub",
    "WPFAppxMicrosoft_WindowsCalculator",
    "WPFAppxClipchamp_Clipchamp",
    "WPFAppxMicrosoft_WindowsAlarms",
    "WPFAppxMicrosoftCorporationII_QuickAssist",
    "WPFAppxMicrosoft_WindowsSoundRecorder",
    "WPFAppxMicrosoft_MicrosoftStickyNotes",
    "WPFAppxMicrosoft_Todos",
    "WPFAppxMicrosoft_MicrosoftSolitaireCollection",
    "WPFAppxMicrosoft_PowerAutomateDesktop",
    "WPFAppxMicrosoft_WindowsDevHome",
    "WPFAppxMicrosoft_BingWeather",
    "WPFAppxMicrosoft_StartExperiencesApp",
    "WPFAppxMicrosoft_BingNews",
    "WPFAppxMicrosoft_Copilot",
    "WPFAppxMicrosoft_BingSearch"
  ]
}
'@ | ConvertFrom-Json
$sync.configs.themes = @'
{
  "shared": {
    "AppEntryWidth": "220",
    "AppEntryFontSize": "13.2",
    "AppEntryIconSize": "28",
    "AppEntryMargin": "3",
    "AppEntryBorderThickness": "1",
    "CustomDialogFontSize": "12",
    "CustomDialogFontSizeHeader": "14",
    "CustomDialogLogoSize": "25",
    "CustomDialogWidth": "400",
    "CustomDialogHeight": "200",
    "FontSize": "12",
    "FontFamily": "Segoe UI",
    "HeaderFontSize": "16",
    "Win11StepTitleFontSize": "22",
    "Win11StepHeroFontSize": "40",
    "Win11LogFontFamily": "Consolas, Monaco",
    "HeaderFontFamily": "Consolas, Cascadia Mono",
    "CheckBoxBulletDecoratorSize": "14",
    "CheckBoxMargin": "15,0,0,2",
    "TabContentMargin": "5",
    "TabButtonFontSize": "14",
    "TabButtonWidth": "110",
    "TabButtonHeight": "26",
    "TabRowHeightInPixels": "50",
    "ToolTipWidth": "300",
    "IconFontSize": "14",
    "IconButtonSize": "35",
    "SettingsIconFontSize": "18",
    "CloseIconFontSize": "12",
    "GroupBorderBackgroundColor": "#232629",
    "ButtonFontSize": "12",
    "ButtonFontFamily": "Segoe UI",
    "ButtonWidth": "200",
    "ButtonHeight": "25",
    "ConfigTabButtonFontSize": "14",
    "ConfigUpdateButtonFontSize": "14",
    "SearchBarWidth": "200",
    "SearchBarHeight": "26",
    "SearchBarTextBoxFontSize": "12",
    "SearchBarClearButtonFontSize": "14",
    "CheckboxMouseOverColor": "#999999",
    "ButtonBorderThickness": "1",
    "ButtonMargin": "1",
    "ButtonCornerRadius": 4
  },
  "Light": {
    "AppInstallUnselectedColor": "#F7F7F7",
    "AppInstallHighlightedColor": "#CFCFCF",
    "AppInstallSelectedColor": "#C2C2C2",
    "ComboBoxForegroundColor": "#232629",
    "ComboBoxBackgroundColor": "#F3F4F6",
    "LabelboxForegroundColor": "#BE123C",
    "MainForegroundColor": "#232629",
    "MainBackgroundColor": "#FFFFFF",
    "LabelBackgroundColor": "#FFFFFF",
    "LinkForegroundColor": "#BE123C",
    "LinkHoverForegroundColor": "#9F1239",
    "ScrollBarBackgroundColor": "#E5E7EB",
    "ScrollBarHoverColor": "#D1D5DB",
    "ScrollBarDraggingColor": "#BE123C",
    "ProgressBarForegroundColor": "#E11D48",
    "ProgressBarErrorColor": "#D13438",
    "ProgressBarWarningColor": "#B36A00",
    "ProgressBarBackgroundColor": "Transparent",
    "ButtonInstallBackgroundColor": "#F7F7F7",
    "ButtonTweaksBackgroundColor": "#F7F7F7",
    "ButtonConfigBackgroundColor": "#F7F7F7",
    "ButtonUpdatesBackgroundColor": "#F7F7F7",
    "ButtonWin11ISOBackgroundColor": "#F7F7F7",
    "ButtonAppxBackgroundColor": "#F7F7F7",
    "ButtonInstallForegroundColor": "#232629",
    "ButtonTweaksForegroundColor": "#232629",
    "ButtonConfigForegroundColor": "#232629",
    "ButtonUpdatesForegroundColor": "#232629",
    "ButtonWin11ISOForegroundColor": "#232629",
    "ButtonAppxForegroundColor": "#232629",
    "ButtonBackgroundColor": "#BE123C",
    "ButtonBackgroundPressedColor": "#881337",
    "ButtonBackgroundMouseoverColor": "#E11D48",
    "ButtonBackgroundSelectedColor": "#F43F5E",
    "ButtonForegroundColor": "#FFF1F2",
    "ToggleButtonOnColor": "#BE123C",
    "ToggleButtonOffColor": "#707070",
    "ToolTipBackgroundColor": "#FFFFFF",
    "BorderColor": "#E4E4E7",
    "BorderOpacity": "0.2"
  },
  "Dark": {
    "AppInstallUnselectedColor": "#16181A",
    "AppInstallHighlightedColor": "#22262A",
    "AppInstallSelectedColor": "#1F6F4A",
    "ComboBoxForegroundColor": "#F7F7F7",
    "ComboBoxBackgroundColor": "#0F1417",
    "LabelboxForegroundColor": "#FB7185",
    "MainForegroundColor": "#F7F7F7",
    "MainBackgroundColor": "#16181A",
    "LabelBackgroundColor": "#16181A",
    "LinkForegroundColor": "#FB7185",
    "LinkHoverForegroundColor": "#FECDD3",
    "ScrollBarBackgroundColor": "#22262A",
    "ScrollBarHoverColor": "#2C3136",
    "ScrollBarDraggingColor": "#E11D48",
    "ProgressBarForegroundColor": "#FB7185",
    "ProgressBarErrorColor": "#FF6B6B",
    "ProgressBarWarningColor": "#FFC83D",
    "ProgressBarBackgroundColor": "Transparent",
    "ButtonInstallBackgroundColor": "#222222",
    "ButtonTweaksBackgroundColor": "#333333",
    "ButtonConfigBackgroundColor": "#444444",
    "ButtonUpdatesBackgroundColor": "#555555",
    "ButtonWin11ISOBackgroundColor": "#666666",
    "ButtonAppxBackgroundColor": "#777777",
    "ButtonInstallForegroundColor": "#F7F7F7",
    "ButtonTweaksForegroundColor": "#F7F7F7",
    "ButtonConfigForegroundColor": "#F7F7F7",
    "ButtonUpdatesForegroundColor": "#F7F7F7",
    "ButtonWin11ISOForegroundColor": "#F7F7F7",
    "ButtonAppxForegroundColor": "#F7F7F7",
    "ButtonBackgroundColor": "#E11D48",
    "ButtonBackgroundPressedColor": "#9F1239",
    "ButtonBackgroundMouseoverColor": "#FB7185",
    "ButtonBackgroundSelectedColor": "#BE123C",
    "ButtonForegroundColor": "#FFF1F2",
    "ToggleButtonOnColor": "#E11D48",
    "ToggleButtonOffColor": "#707070",
    "ToolTipBackgroundColor": "#1B1F23",
    "BorderColor": "#241A1D",
    "BorderOpacity": 0.35
  }
}
'@ | ConvertFrom-Json
$sync.configs.tweaks = @'
{
  "WPFTweaksActivity": {
    "Content": "Activity History - Disable",
    "Description": "Stops Windows from publishing or uploading user activities while preserving clipboard history.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "EnableActivityFeed",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "PublishUserActivities",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "UploadUserActivities",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/activity"
  },
  "WPFTweaksHiber": {
    "Content": "Hibernation - Disable",
    "Description": "Hibernation is really meant for laptops as it saves what's in memory before turning the PC off. It really should never be used.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\System\\CurrentControlSet\\Control\\Session Manager\\Power",
        "Name": "HibernateEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Explorer\\FlyoutMenuSettings",
        "Name": "ShowHibernateOption",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      }
    ],
    "InvokeScript": [
      "powercfg.exe /hibernate off"
    ],
    "UndoScript": [
      "powercfg.exe /hibernate on"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/hiber"
  },
  "WPFTweaksWidget": {
    "Content": "Widgets - Remove",
    "Description": "Removes the annoying widgets in the bottom left of the Taskbar.",
    "category": "Essential Tweaks",
    "panel": "1",
    "InvokeScript": [
      "\r\n      # Sometimes if you dont stop the Widgets process the removal may fail\r\n\r\n      Get-Process *Widget* | Stop-Process\r\n      Get-AppxPackage Microsoft.WidgetsPlatformRuntime -AllUsers | Remove-AppxPackage -AllUsers\r\n      Get-AppxPackage MicrosoftWindows.Client.WebExperience -AllUsers | Remove-AppxPackage -AllUsers\r\n\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      Write-Host \"Removed widgets\"\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/widget"
  },
  "WPFTweaksRevertStartMenu": {
    "Content": "Start Menu Previous Layout - Enable",
    "Description": "Bring back the old Start Menu layout from before the gradual rollout of the new one in 25H2. On newer versions of Windows !!THIS TWEAK WILL NOT WORK!!",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\ControlSet001\\Control\\FeatureManagement\\Overrides\\8\\3036241548",
        "Name": "EnabledState",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/revertstartmenu"
  },
  "WPFTweaksDisableStoreSearch": {
    "Content": "Microsoft Store Recommended Search Results - Disable",
    "Description": "Will not display recommended Microsoft Store apps when searching for apps in the Start menu.",
    "category": "Essential Tweaks",
    "panel": "1",
    "InvokeScript": [
      "icacls \"$Env:LocalAppData\\Packages\\Microsoft.WindowsStore_8wekyb3d8bbwe\\LocalState\\store.db\" /deny *S-1-1-0:F"
    ],
    "UndoScript": [
      "icacls \"$Env:LocalAppData\\Packages\\Microsoft.WindowsStore_8wekyb3d8bbwe\\LocalState\\store.db\" /grant *S-1-1-0:F"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/disablestoresearch"
  },
  "WPFTweaksLocation": {
    "Content": "Location Tracking - Disable",
    "Description": "Disables Location Tracking.",
    "category": "Essential Tweaks",
    "panel": "1",
    "service": [
      {
        "Name": "lfsvc",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      }
    ],
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\CapabilityAccessManager\\ConsentStore\\location",
        "Name": "Value",
        "Value": "Deny",
        "Type": "String",
        "OriginalValue": "Allow"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Sensor\\Overrides\\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}",
        "Name": "SensorPermissionState",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SYSTEM\\Maps",
        "Name": "AutoUpdateEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/location"
  },
  "WPFTweaksServices": {
    "Content": "Services - Set to Manual",
    "Description": "Sets some services to Manual startup and adjusts the SvcHostSplitThresholdInKB registry value to better match system memory, which can significantly reduce the number of svchost.exe processes.",
    "category": "Essential Tweaks",
    "panel": "1",
    "service": [
      {
        "Name": "CscService",
        "StartupType": "Disabled",
        "OriginalType": "Manual"
      },
      {
        "Name": "DiagTrack",
        "StartupType": "Disabled",
        "OriginalType": "Automatic"
      },
      {
        "Name": "MapsBroker",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "StorSvc",
        "StartupType": "Manual",
        "OriginalType": "Automatic"
      },
      {
        "Name": "SharedAccess",
        "StartupType": "Disabled",
        "OriginalType": "Automatic"
      }
    ],
    "InvokeScript": [
      "\r\n      $Memory = (Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum).Sum / 1KB\r\n      Set-ItemProperty -Path \"HKLM:\\SYSTEM\\CurrentControlSet\\Control\" -Name SvcHostSplitThresholdInKB -Value $Memory\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/services"
  },
  "WPFTweaksBraveDebloat": {
    "Content": "Brave Browser - Debloat",
    "Description": "Disables various annoyances like Brave Rewards, Leo AI, Crypto Wallet and VPN.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveRewardsDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveWalletDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveVPNDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveAIChatEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveStatsPingEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveNewsDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveTalkDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "TorDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "BraveP3AEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "UrlKeyedAnonymizedDataCollectionEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "SafeBrowsingExtendedReportingEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\BraveSoftware\\Brave",
        "Name": "MetricsReportingEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/bravedebloat"
  },
  "WPFTweaksDisableWarningForUnsignedRdp": {
    "Content": "RDP Unsigned File Warnings - Disable",
    "Description": "Disables warnings shown when launching unsigned RDP files introduced with the latest Windows 10 and 11 updates.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services\\Client",
        "Name": "RedirectionWarningDialogVersion",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Terminal Server Client",
        "Name": "RdpLaunchConsentAccepted",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/disablewarningforunsignedrdp"
  },
  "WPFTweaksEdgeDebloat": {
    "Content": "Microsoft Edge - Debloat",
    "Description": "Disables various telemetry options, popups, and other annoyances in Edge.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\EdgeUpdate",
        "Name": "CreateDesktopShortcutDefault",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "PersonalizationReportingEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge\\ExtensionInstallBlocklist",
        "Name": "1",
        "Value": "ofefcgjbeghpigppfmkologfjadafddi",
        "Type": "String",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "ShowRecommendationsEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "HideFirstRunExperience",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "UserFeedbackAllowed",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "ConfigureDoNotTrack",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "AlternateErrorPagesEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "EdgeCollectionsEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "EdgeShoppingAssistantEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "MicrosoftEdgeInsiderPromotionEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "ShowMicrosoftRewards",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "WebWidgetAllowed",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "DiagnosticData",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "EdgeAssetDeliveryServiceEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "WalletDonationEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Edge",
        "Name": "DefaultBrowserSettingsCampaignEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/edgedebloat"
  },
  "WPFTweaksConsumerFeatures": {
    "Content": "ConsumerFeatures - Disable",
    "Description": "Stops promoted app installs and reduces app suggestions from Microsoft Store content.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\CloudContent",
        "Name": "DisableWindowsConsumerFeatures",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/consumerfeatures"
  },
  "WPFTweaksTelemetry": {
    "Content": "Telemetry - Disable",
    "Description": "Disables Microsoft Telemetry.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\AdvertisingInfo",
        "Name": "Enabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Privacy",
        "Name": "TailoredExperiencesWithDiagnosticDataEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Speech_OneCore\\Settings\\OnlineSpeechPrivacy",
        "Name": "HasAccepted",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Input\\TIPC",
        "Name": "Enabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\InputPersonalization",
        "Name": "RestrictImplicitInkCollection",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\InputPersonalization",
        "Name": "RestrictImplicitTextCollection",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\InputPersonalization\\TrainedDataStore",
        "Name": "HarvestContacts",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Personalization\\Settings",
        "Name": "AcceptedPrivacyPolicy",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\DataCollection",
        "Name": "AllowTelemetry",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "Start_TrackProgs",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "PublishUserActivities",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Siuf\\Rules",
        "Name": "NumberOfSIUFInPeriod",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "InvokeScript": [
      "\r\n      # Disable Defender Auto Sample Submission\r\n      Set-MpPreference -SubmitSamplesConsent 2\r\n\r\n      # Disable (Connected User Experiences and Telemetry) Service\r\n      Set-Service -Name diagtrack -StartupType Disabled\r\n\r\n      # Disable (Windows Error Reporting Manager) Service\r\n      Set-Service -Name wermgr -StartupType Disabled\r\n\r\n      # Disable PowerShell 7 telemetry\r\n      [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')\r\n\r\n      Remove-ItemProperty -Path \"HKCU:\\Software\\Microsoft\\Siuf\\Rules\" -Name PeriodInNanoSeconds\r\n      "
    ],
    "UndoScript": [
      "\r\n      # Enable Defender Auto Sample Submission\r\n      Set-MpPreference -SubmitSamplesConsent 1\r\n\r\n      # Enable (Connected User Experiences and Telemetry) Service\r\n      Set-Service -Name diagtrack -StartupType Automatic\r\n\r\n      # Enable (Windows Error Reporting Manager) Service\r\n      Set-Service -Name wermgr -StartupType Automatic\r\n\r\n      # Enable PowerShell 7 telemetry\r\n      [Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '', 'Machine')\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/telemetry"
  },
  "WPFTweaksDeliveryOptimization": {
    "Content": "Delivery Optimization - Disable",
    "Description": "Stops Windows from using your bandwidth to upload updates to other PCs on the internet or local network.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DeliveryOptimization",
        "Name": "DODownloadMode",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/deliveryoptimization"
  },
  "WPFTweaksRemoveEdge": {
    "Content": "Microsoft Edge - Remove",
    "Description": "Uninstalls Microsoft Edge by creating dummy MicrosoftEdge.exe file in the legacy Edge folder. This tricks Windows into unlocking the official Edge uninstaller allowing for a system-level removal.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "InvokeScript": [
      "\r\n      $Path = Resolve-Path -Path \"$Env:ProgramFiles (x86)\\Microsoft\\Edge\\Application\\*\\Installer\\setup.exe\" | Select-Object -Last 1\r\n\r\n      if (Test-Path $Path) {\r\n          New-Item -Path \"$Env:SystemRoot\\SystemApps\\Microsoft.MicrosoftEdge_8wekyb3d8bbwe\\MicrosoftEdge.exe\" -Force\r\n          Start-Process -FilePath $Path -ArgumentList \"--uninstall --system-level --force-uninstall --delete-profile\" -Wait\r\n          Write-Host \"Microsoft Edge was removed\"\r\n      } else {\r\n          Write-Host \"Microsoft Edge is not installed\"\r\n      }\r\n      "
    ],
    "UndoScript": [
      "\r\n      Write-Host \"Installing Microsoft Edge...\"\r\n      winget install Microsoft.Edge --source winget\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/removeedge"
  },
  "WPFTweaksDisableBitLocker": {
    "Content": "BitLocker - Disable",
    "Description": "Disables BitLocker.",
    "category": "Essential Tweaks",
    "panel": "1",
    "InvokeScript": [
      "Disable-BitLocker -MountPoint $Env:SystemDrive"
    ],
    "UndoScript": [
      "Enable-BitLocker -MountPoint $Env:SystemDrive"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/disablebitlocker"
  },
  "WPFTweaksUTC": {
    "Content": "Date & Time - Set Time to UTC",
    "Description": "Essential for computers that are dual booting. Fixes the time sync with Linux systems.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\TimeZoneInformation",
        "Name": "RealTimeIsUniversal",
        "Value": "1",
        "Type": "QWord",
        "OriginalValue": "0"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/utc"
  },
  "WPFTweaksRemoveOneDrive": {
    "Content": "Microsoft OneDrive - Remove",
    "Description": "Denies permission to remove OneDrive user files, then uses its own uninstaller to remove it and restores the original permission afterward.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "InvokeScript": [
      "\r\n      # Deny permission to remove OneDrive folder\r\n      icacls $Env:OneDrive /deny \"*S-1-5-32-544:(D,DC)\"\r\n\r\n      Write-Host \"Uninstalling OneDrive...\"\r\n      Start-Process -FilePath (Join-Path $Env:SystemRoot \"System32\\OneDriveSetup.exe\") -ArgumentList '/uninstall' -Wait\r\n\r\n      # Some of OneDrive files use explorer, and OneDrive uses FileCoAuth\r\n      Write-Host \"Removing leftover OneDrive Files...\"\r\n\r\n      Stop-Process -Name FileCoAuth,Explorer\r\n\r\n      Remove-Item \"$Env:LocalAppData\\Microsoft\\OneDrive\" -Recurse -Force\r\n      Remove-Item \"$Env:ProgramData\\Microsoft OneDrive\" -Recurse -Force\r\n\r\n      # Grant back permission to access OneDrive folder\r\n      icacls $Env:OneDrive /grant \"*S-1-5-32-544:(D,DC)\"\r\n\r\n      if (-not (Get-ChildItem -Path $Env:OneDrive)) {\r\n          Remove-Item -Path $Env:OneDrive -Recurse\r\n          [Environment]::SetEnvironmentVariable('OneDrive', $null, 'User')\r\n      }\r\n\r\n      # Disable OneSyncSvc\r\n      Set-Service -Name OneSyncSvc -StartupType Disabled\r\n      "
    ],
    "UndoScript": [
      "\r\n      Write-Host \"Installing OneDrive\"\r\n      winget install Microsoft.Onedrive --source winget\r\n\r\n      # Enabled OneSyncSvc\r\n      Set-Service -Name OneSyncSvc -StartupType Automatic\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/removeonedrive"
  },
  "WPFTweaksRemoveHomeAndGallery": {
    "Content": "File Explorer Home and Gallery - Disable",
    "Description": "Removes the Home and Gallery from Explorer and sets This PC as default.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Classes\\CLSID\\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}",
        "Name": "System.IsPinnedToNameSpaceTree",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Classes\\CLSID\\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}",
        "Name": "System.IsPinnedToNameSpaceTree",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "LaunchTo",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/removehomeandgallery"
  },
  "WPFTweaksDisplay": {
    "Content": "Visual Effects - Set to Best Performance",
    "Description": "Sets the system preferences to performance. You can do this manually with sysdm.cpl as well.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Control Panel\\Desktop",
        "Name": "DragFullWindows",
        "Value": "0",
        "Type": "String",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Control Panel\\Desktop",
        "Name": "MenuShowDelay",
        "Value": "200",
        "Type": "String",
        "OriginalValue": "400"
      },
      {
        "Path": "HKCU:\\Control Panel\\Desktop\\WindowMetrics",
        "Name": "MinAnimate",
        "Value": "0",
        "Type": "String",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Control Panel\\Keyboard",
        "Name": "KeyboardDelay",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "ListviewAlphaSelect",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "ListviewShadow",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "TaskbarAnimations",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\VisualEffects",
        "Name": "VisualFXSetting",
        "Value": "3",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\DWM",
        "Name": "EnableAeroPeek",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "TaskbarMn",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "ShowTaskViewButton",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search",
        "Name": "SearchboxTaskbarMode",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      }
    ],
    "InvokeScript": [
      "Set-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\" -Type Binary -Value ([byte[]](144,18,3,128,16,0,0,0))"
    ],
    "UndoScript": [
      "Remove-ItemProperty -Path \"HKCU:\\Control Panel\\Desktop\" -Name \"UserPreferencesMask\""
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/display"
  },
  "WPFTweaksReservedStorage": {
    "Content": "Disable Reserved Storage",
    "Description": "Disables Windows Reserved Storage (7-10 GB held for updates/temp files). Recommended only on small drives. Re-enable before major Windows feature updates to avoid installation failures.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "InvokeScript": [
      "DISM /Online /Set-ReservedStorageState /State:Disabled"
    ],
    "UndoScript": [
      "DISM /Online /Set-ReservedStorageState /State:Enabled"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/reservedstorage"
  },
  "WPFTweaksRestorePoint": {
    "Content": "Restore Point - Create",
    "Description": "Creates a restore point at runtime in case a revert is needed from taured modifications.",
    "category": "Essential Tweaks",
    "panel": "1",
    "Checked": "False",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\SystemRestore",
        "Name": "SystemRestorePointCreationFrequency",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1440"
      }
    ],
    "InvokeScript": [
      "\r\n      if (-not (Get-ComputerRestorePoint)) {\r\n          Enable-ComputerRestore -Drive $Env:SystemDrive\r\n      }\r\n\r\n      Checkpoint-Computer -Description \"System Restore Point created by taured\" -RestorePointType MODIFY_SETTINGS\r\n      Write-Host \"System Restore Point Created Successfully\" -ForegroundColor Green\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/restorepoint"
  },
  "WPFTweaksEndTaskOnTaskbar": {
    "Content": "End Task With Right Click - Enable",
    "Description": "Enables option to end task when right-clicking a program in the taskbar.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced\\TaskbarDeveloperSettings",
        "Name": "TaskbarEndTask",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/endtaskontaskbar"
  },
  "WPFTweaksStorage": {
    "Content": "Storage Sense - Disable",
    "Description": "Storage Sense deletes temp files automatically.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\StorageSense\\Parameters\\StoragePolicy",
        "Name": "01",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/storage"
  },
  "WPFTweaksWindowsAI": {
    "Content": "Windows AI - Disable And Remove",
    "Description": "Removes and disables all AI features/packages",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer",
        "Name": "SettingsPageVisibility",
        "Value": "hide:aicomponents",
        "Type": "String",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\WindowsNotepad",
        "Name": "DisableAIFeatures",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "InvokeScript": [
      "\r\n      $Appx = (Get-AppxPackage MicrosoftWindows.Client.CoreAI).PackageFullName\r\n      $Sid = (Get-LocalUser $Env:UserName).Sid.Value\r\n\r\n      New-Item \"HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Appx\\AppxAllUserStore\\EndOfLife\\$Sid\\$Appx\" -Force\r\n\r\n      Get-AppxPackage -AllUsers \"*Copilot*\" | Remove-AppxPackage -AllUsers\r\n      winget uninstall -e --name \"Copilot\" --silent --force --accept-source-agreements 2>$null\r\n      Get-AppxPackage -AllUsers Microsoft.MicrosoftOfficeHub | Remove-AppxPackage -AllUsers\r\n\r\n      if ($Appx) {\r\n          Remove-AppxPackage $Appx\r\n      }\r\n\r\n      Set-Service -Name WSAIFabricSvc -StartupType Disabled\r\n      Disable-WindowsOptionalFeature -FeatureName Recall -Online -NoRestart\r\n\r\n      Write-Host \"Windows AI Disabled\"\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/windowsai"
  },
  "WPFTweaksWPBT": {
    "Content": "Windows Platform Binary Table (WPBT) - Disable",
    "Description": "If enabled, WPBT allows your computer vendor to execute programs at boot time, such as anti-theft software, software drivers, as well as force install software without user consent. Poses potential security risk.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Session Manager",
        "Name": "DisableWpbtExecution",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/wpbt"
  },
  "WPFTweaksPreventDeviceMetadataFromNetwork": {
    "Content": "Prevent Device Companion Apps",
    "Description": "Prevents additional software from being installed when plugging in devices (e.g. Ads when plugging in a monitor). Poses potential security risk.",
    "category": "Essential Tweaks",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Device Metadata",
        "Name": "PreventDeviceMetadataFromNetwork",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/preventdevicemetadatafromnetwork"
  },
  "WPFTweaksRazerBlock": {
    "Content": "Razer Software Auto-Install - Disable",
    "Description": "Blocks ALL Razer Software installations. The hardware works fine without any software.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\DriverSearching",
        "Name": "SearchOrderConfig",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Device Installer",
        "Name": "DisableCoInstallers",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0"
      }
    ],
    "InvokeScript": [
      "\r\n      $RazerPath = \"$Env:SystemRoot\\Installer\\Razer\"\r\n\r\n      if (Test-Path $RazerPath) {\r\n        Remove-Item $RazerPath\\* -Recurse -Force\r\n      } else {\r\n        New-Item -Path $RazerPath -ItemType Directory\r\n      }\r\n\r\n      icacls $RazerPath /deny \"*S-1-1-0:(W)\"\r\n      "
    ],
    "UndoScript": [
      "\r\n      icacls \"$Env:SystemRoot\\Installer\\Razer\" /remove:d *S-1-1-0\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/razerblock"
  },
  "WPFTweaksLogiBlock": {
    "Content": "Logitech Download Assistant Auto-Install - Disable",
    "Description": "Blocks the Logi Download Assistant that Windows Update keeps reinstalling with Logitech device drivers. Logitech hardware keeps working without it.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "InvokeScript": [
      "\r\n      Stop-Process -Name \"logi_download_assistant\" -Force -ErrorAction SilentlyContinue\r\n\r\n      $ProgramFiles64 = if ($Env:ProgramW6432) { $Env:ProgramW6432 } else { $Env:ProgramFiles }\r\n      $LogiPath = \"$ProgramFiles64\\LogiDownloadAssistant\"\r\n\r\n      if (Test-Path $LogiPath) {\r\n        Remove-Item $LogiPath\\* -Recurse -Force\r\n      } else {\r\n        New-Item -Path $LogiPath -ItemType Directory\r\n      }\r\n\r\n      icacls $LogiPath /deny \"*S-1-1-0:(W)\"\r\n      if ($LASTEXITCODE -ne 0) { throw \"icacls failed to deny write access on $LogiPath (exit code $LASTEXITCODE)\" }\r\n      "
    ],
    "UndoScript": [
      "\r\n      $ProgramFiles64 = if ($Env:ProgramW6432) { $Env:ProgramW6432 } else { $Env:ProgramFiles }\r\n      $LogiPath = \"$ProgramFiles64\\LogiDownloadAssistant\"\r\n\r\n      if (Test-Path $LogiPath) {\r\n        icacls $LogiPath /remove:d \"*S-1-1-0\"\r\n        if ($LASTEXITCODE -ne 0) { throw \"icacls failed to remove the write-deny rule on $LogiPath (exit code $LASTEXITCODE)\" }\r\n      }\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/logiblock"
  },
  "WPFTweaksDisableNotifications": {
    "Content": "System Tray Notifications & Calendar - Disable",
    "Description": "Disables all Notifications INCLUDING Calendar.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Policies\\Microsoft\\Windows\\Explorer",
        "Name": "DisableNotificationCenter",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\PushNotifications",
        "Name": "ToastEnabled",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/disablenotifications"
  },
  "WPFTweaksBlockAdobeNet": {
    "Content": "Adobe URL Block List - Enable",
    "Description": "Reduces user interruptions by selectively blocking connections to Adobe's activation and telemetry servers. Credit: Ruddernation-Designs",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "InvokeScript": [
      "\r\n      $hostsUrl = Invoke-RestMethod -Uri https://github.com/Ruddernation-Designs/Adobe-URL-Block-List/raw/refs/heads/master/hosts\r\n      Add-Content -Path \"$Env:SystemRoot\\System32\\drivers\\etc\\hosts\" -Value $hostsUrl\r\n\r\n      ipconfig /flushdns\r\n      Write-Host 'Added Adobe url block list from host file'\r\n      "
    ],
    "UndoScript": [
      "\r\n      Set-Content \"$Env:SystemRoot\\System32\\drivers\\etc\\hosts\" (\r\n          (Get-Content \"$Env:SystemRoot\\System32\\drivers\\etc\\hosts\") -join \"`n\" -replace '(?s)#New Ver.*', ''\r\n      )\r\n\r\n      ipconfig /flushdns\r\n      Write-Host 'Removed Adobe url block list from host file'\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/blockadobenet"
  },
  "WPFTweaksRightClickMenu": {
    "Content": "Right-Click Menu Previous Layout - Enable",
    "Description": "Restores the classic context menu when right-clicking in File Explorer, replacing the simplified Windows 11 version.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "InvokeScript": [
      "\r\n      New-Item -Path \"HKCU:\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\" -Name InprocServer32 -Value \"\" -Force\r\n      Stop-Process -Name explorer\r\n      "
    ],
    "UndoScript": [
      "Remove-Item -Path \"HKCU:\\Software\\Classes\\CLSID\\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\" -Recurse"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/rightclickmenu"
  },
  "WPFTweaksDiskCleanup": {
    "Content": "Disk Cleanup - Run",
    "Description": "Runs Disk Cleanup on Drive C: and removes old Windows Updates.",
    "category": "Essential Tweaks",
    "panel": "1",
    "InvokeScript": [
      "\r\n      cleanmgr.exe /d C: /VERYLOWDISK\r\n      Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/diskcleanup"
  },
  "WPFTweaksDeleteTempFiles": {
    "Content": "Temporary Files - Remove",
    "Description": "Erases TEMP Folders.",
    "category": "Essential Tweaks",
    "panel": "1",
    "InvokeScript": [
      "\r\n      # A temp folder always holds files something has open, including this run's own, and\r\n      # the job layer counts a logged error as a failed step\r\n      Remove-Item -Path \"$Env:Temp\\*\" -Recurse -Force -ErrorAction SilentlyContinue\r\n      Remove-Item -Path \"$Env:SystemRoot\\Temp\\*\" -Recurse -Force -ErrorAction SilentlyContinue\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/deletetempfiles"
  },
  "WPFTweaksIPv46": {
    "Content": "IPv6 - Set IPv4 as Preferred",
    "Description": "Setting the IPv4 preference can have latency and security benefits on private networks where IPv6 is not configured.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters",
        "Name": "DisabledComponents",
        "Value": "32",
        "Type": "DWord",
        "OriginalValue": "0"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/ipv46"
  },
  "WPFTweaksTeredo": {
    "Content": "Teredo - Disable",
    "Description": "Teredo network tunneling is an IPv6 feature that can cause additional latency, but may cause problems with some games.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters",
        "Name": "DisabledComponents",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0"
      }
    ],
    "InvokeScript": [
      "netsh interface teredo set state disabled"
    ],
    "UndoScript": [
      "netsh interface teredo set state default"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/teredo"
  },
  "WPFTweaksDisableIPv6": {
    "Content": "IPv6 - Disable",
    "Description": "Disables IPv6.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip6\\Parameters",
        "Name": "DisabledComponents",
        "Value": "255",
        "Type": "DWord",
        "OriginalValue": "0"
      }
    ],
    "InvokeScript": [
      "Disable-NetAdapterBinding -Name * -ComponentID ms_tcpip6"
    ],
    "UndoScript": [
      "Enable-NetAdapterBinding -Name * -ComponentID ms_tcpip6"
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/disableipv6"
  },
  "WPFTweaksDisableBGapps": {
    "Content": "Background Apps - Disable",
    "Description": "Disables all Microsoft Store apps from running in the background, which has to be done individually since Windows 11.",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\BackgroundAccessApplications",
        "Name": "GlobalUserDisabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/disablebgapps"
  },
  "WPFTweaksDisableExplorerAutoDiscovery": {
    "Content": "File Explorer Automatic Folder Discovery - Disable",
    "Description": "Windows Explorer automatically tries to guess the type of the folder based on its contents, slowing down the browsing experience. WARNING! Will disable File Explorer grouping.",
    "category": "Essential Tweaks",
    "panel": "1",
    "InvokeScript": [
      "\r\n      # Previously detected folders\r\n      $bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"\r\n\r\n      # Folder types lookup table\r\n      $bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"\r\n\r\n      # Flush Explorer view database\r\n      Remove-Item -Path $bags -Recurse -Force\r\n      Write-Host \"Removed $bags\"\r\n\r\n      Remove-Item -Path $bagMRU -Recurse -Force\r\n      Write-Host \"Removed $bagMRU\"\r\n\r\n      # Every folder\r\n      $allFolders = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\\AllFolders\\Shell\"\r\n\r\n      if (!(Test-Path $allFolders)) {\r\n        New-Item -Path $allFolders -Force\r\n        Write-Host \"Created $allFolders\"\r\n      }\r\n\r\n      # Generic view\r\n      New-ItemProperty -Path $allFolders -Name \"FolderType\" -Value \"NotSpecified\" -PropertyType String -Force\r\n      Write-Host \"Set FolderType to NotSpecified\"\r\n\r\n      Write-Host Please sign out and back in, or restart your computer to apply the changes!\r\n      "
    ],
    "UndoScript": [
      "\r\n      # Previously detected folders\r\n      $bags = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\Bags\"\r\n\r\n      # Folder types lookup table\r\n      $bagMRU = \"HKCU:\\Software\\Classes\\Local Settings\\Software\\Microsoft\\Windows\\Shell\\BagMRU\"\r\n\r\n      # Flush Explorer view database\r\n      Remove-Item -Path $bags -Recurse -Force\r\n      Write-Host \"Removed $bags\"\r\n\r\n      Remove-Item -Path $bagMRU -Recurse -Force\r\n      Write-Host \"Removed $bagMRU\"\r\n\r\n      Write-Host Please sign out and back in, or restart your computer to apply the changes!\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/essential-tweaks/disableexplorerautodiscovery"
  },
  "WPFToggleDetailedBSoD": {
    "Content": "BSoD Verbose Mode",
    "Description": "Gives more information when you blue screen.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\CrashControl",
        "Name": "DisplayParameters",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "false"
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\CrashControl",
        "Name": "DisableEmoticon",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/detailedbsod"
  },
  "WPFToggleBatteryPercentage": {
    "Content": "System Tray Battery Percentage",
    "Description": "Shows numeric battery percentage next to the battery icon in the system tray.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "IsBatteryPercentageEnabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/batterypercentage"
  },
  "WPFToggleDarkMode": {
    "Content": "Dark Theme for Windows",
    "Description": "Dark Mode for the system and applications.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        "Name": "AppsUseLightTheme",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "false"
      },
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        "Name": "SystemUsesLightTheme",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "false"
      }
    ],
    "InvokeScript": [
      "\r\n      Invoke-tauredExplorerUpdate\r\n      if ($sync.ThemeButton.Content -eq [char]0xF08C) {\r\n        Invoke-WinutilThemeChange -theme \"Auto\"\r\n      }\r\n      "
    ],
    "UndoScript": [
      "\r\n      Invoke-tauredExplorerUpdate\r\n      if ($sync.ThemeButton.Content -eq [char]0xF08C) {\r\n        Invoke-WinutilThemeChange -theme \"Auto\"\r\n      }\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/darkmode"
  },
  "WPFToggleShowExt": {
    "Content": "File Explorer File Extensions",
    "Description": "Shows .file extensions in Explorer (.exe, .png, etc.)",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "HideFileExt",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "false"
      }
    ],
    "InvokeScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "UndoScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/showext"
  },
  "WPFToggleHiddenFiles": {
    "Content": "File Explorer Hidden Files",
    "Description": "Reveals hidden files in Explorer.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "Hidden",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "false"
      }
    ],
    "InvokeScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "UndoScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/hiddenfiles"
  },
  "WPFToggleVerboseLogon": {
    "Content": "Logon Verbose Mode",
    "Description": "Show detailed messages during startup/shutdown.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System",
        "Name": "VerboseStatus",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/verboselogon"
  },
  "WPFToggleNewOutlook": {
    "Content": "Microsoft Outlook New Version",
    "Description": "This will ensure the new Outlook application is used.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\SOFTWARE\\Microsoft\\Office\\16.0\\Outlook\\Preferences",
        "Name": "UseNewOutlook",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\Office\\16.0\\Outlook\\Options\\General",
        "Name": "HideNewOutlookToggle",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "true"
      },
      {
        "Path": "HKCU:\\Software\\Policies\\Microsoft\\Office\\16.0\\Outlook\\Options\\General",
        "Name": "DoNewOutlookAutoMigration",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "false"
      },
      {
        "Path": "HKCU:\\Software\\Policies\\Microsoft\\Office\\16.0\\Outlook\\Preferences",
        "Name": "NewOutlookMigrationUserSetting",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/newoutlook"
  },
  "WPFToggleScrollbars": {
    "Content": "Scrollbars Always Visible",
    "Description": "If enabled, scrollbars will always be visible. If disabled, Windows will automatically hide scrollbars when not in use.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Control Panel\\Accessibility",
        "Name": "DynamicScrollbars",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/scrollbars"
  },
  "WPFMultiplaneOverlay": {
    "Content": "Multiplane Overlay",
    "Description": "Multiplane Overlay composes multiple image layers, which can sometimes cause issues with graphics cards. Changes to this preference are applied immediately.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Combobox",
    "ComboItems": "Enabled|Disabled (Compatibility)|Fully Disabled",
    "ComboDescriptions": {
      "Enabled": "Uses Windows' default overlay behavior.",
      "Disabled (Compatibility)": "Disables MPO using OverlayTestMode=5, the less aggressive compatibility method.",
      "Fully Disabled": "Disables MPO using OverlayTestMode=5 and DisableOverlays=1, the more aggressive method."
    },
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\Windows\\Dwm",
        "Name": "OverlayTestMode",
        "Type": "DWord",
        "DefaultValue": "0",
        "Values": {
          "Enabled": "<RemoveEntry>",
          "Disabled (Compatibility)": "5",
          "Fully Disabled": "5"
        }
      },
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\GraphicsDrivers",
        "Name": "DisableOverlays",
        "Type": "DWord",
        "DefaultValue": "0",
        "Values": {
          "Enabled": "<RemoveEntry>",
          "Disabled (Compatibility)": "<RemoveEntry>",
          "Fully Disabled": "1"
        }
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/multiplaneoverlay"
  },
  "WPFToggleMouseAcceleration": {
    "Content": "Mouse Acceleration",
    "Description": "Makes it so Cursor movement is affected by the speed of your physical mouse movements.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Control Panel\\Mouse",
        "Name": "MouseSpeed",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      },
      {
        "Path": "HKCU:\\Control Panel\\Mouse",
        "Name": "MouseThreshold1",
        "Value": "6",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      },
      {
        "Path": "HKCU:\\Control Panel\\Mouse",
        "Name": "MouseThreshold2",
        "Value": "10",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/mouseacceleration"
  },
  "WPFToggleNumLock": {
    "Content": "Num Lock on Startup",
    "Description": "Toggle the Num Lock key state when your computer starts.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKU:\\.Default\\Control Panel\\Keyboard",
        "Name": "InitialKeyboardIndicators",
        "Value": "2",
        "Type": "String",
        "OriginalValue": "0",
        "DefaultState": "false"
      },
      {
        "Path": "HKCU:\\Control Panel\\Keyboard",
        "Name": "InitialKeyboardIndicators",
        "Value": "2",
        "Type": "String",
        "OriginalValue": "0",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/numlock"
  },
  "WPFToggleWindowSnapping": {
    "Content": "Window Snapping",
    "Description": "Toggles the window snapping feature when dragging windows.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Control Panel\\Desktop",
        "Name": "WindowArrangementActive",
        "Value": "1",
        "Type": "String",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/windowsnapping"
  },
  "WPFToggleStandbyFix": {
    "Content": "S0 Sleep Network Connectivity",
    "Description": "Toggles network connectivity during S0 Sleep which is low power idle in modern laptops.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\SOFTWARE\\Policies\\Microsoft\\Power\\PowerSettings\\f15576e8-98b7-4186-b944-eafa664402d9",
        "Name": "ACSettingIndex",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/standbyfix"
  },
  "WPFToggleS3Sleep": {
    "Content": "S3 Sleep",
    "Description": "Toggles between Modern Standby and S3 Sleep, which cuts off power to the CPU while continuing to refresh the memory.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Power",
        "Name": "PlatformAoAcOverride",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/s3sleep"
  },
  "WPFToggleHideSettingsHome": {
    "Content": "Settings Home Page",
    "Description": "Toggles the Home Page in the Windows Settings app.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Explorer",
        "Name": "SettingsPageVisibility",
        "Value": "show:home",
        "Type": "String",
        "OriginalValue": "hide:home",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/hidesettingshome"
  },
  "WPFToggleBingSearch": {
    "Content": "Start Menu Bing Search",
    "Description": "Toggles Bing web search results in Windows Search.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search",
        "Name": "BingSearchEnabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/bingsearch"
  },
  "WPFToggleLoginBlur": {
    "Content": "Logon Screen Acrylic Blur",
    "Description": "Toggles the acrylic blur effect on login screen background.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\System",
        "Name": "DisableAcrylicBackgroundOnLogon",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/loginblur"
  },
  "WPFToggleDisableLockscreen": {
    "Content": "Lock Screen - Disable",
    "Description": "Skips the lock screen entirely and goes directly to the sign-in screen on boot and wake.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Personalization",
        "Name": "NoLockScreen",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "<RemoveEntry>"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/disablelockscreen"
  },
  "WPFToggleStartMenuRecommendations": {
    "Content": "Start Menu Recommendations",
    "Description": "Toggles the recommendations section in the Start Menu. WARNING: This will also disable Windows Spotlight on your Lock Screen as a side effect.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\PolicyManager\\current\\device\\Start",
        "Name": "HideRecommendedSection",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "true"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Microsoft\\PolicyManager\\current\\device\\Education",
        "Name": "IsEducationEnvironment",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "true"
      },
      {
        "Path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\Explorer",
        "Name": "HideRecommendedSection",
        "Value": "0",
        "Type": "DWord",
        "OriginalValue": "1",
        "DefaultState": "true"
      }
    ],
    "InvokeScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "UndoScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/startmenurecommendations"
  },
  "WPFToggleStickyKeys": {
    "Content": "Sticky Keys",
    "Description": "Toggles the Sticky Keys, which activate when clicking shift rapidly.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Control Panel\\Accessibility\\StickyKeys",
        "Name": "Flags",
        "Value": "506",
        "Type": "DWord",
        "OriginalValue": "58",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/stickykeys"
  },
  "WPFToggleTaskbarAlignment": {
    "Content": "Taskbar Centered Icons",
    "Description": "Toggles the Taskbar alignment either to the left or center.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "TaskbarAl",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "InvokeScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "UndoScript": [
      "\r\n      Invoke-tauredExplorerUpdate -action \"restart\"\r\n      "
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/taskbaralignment"
  },
  "WPFToggleTaskbarSearch": {
    "Content": "Taskbar Search Icon",
    "Description": "Toggles the Search Button on the Taskbar.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Search",
        "Name": "SearchboxTaskbarMode",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/taskbarsearch"
  },
  "WPFToggleTaskView": {
    "Content": "Taskbar Task View Icon",
    "Description": "Toggles the Task View Button in the Taskbar.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Advanced",
        "Name": "ShowTaskViewButton",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/taskview"
  },
  "WPFToggleGameMode": {
    "Content": "Game Mode",
    "Description": "Toggles Windows prioritizes gaming performance by allocating system resources to games.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKCU:\\Software\\Microsoft\\GameBar",
        "Name": "AllowAutoGameMode",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      },
      {
        "Path": "HKCU:\\Software\\Microsoft\\GameBar",
        "Name": "AutoGameModeEnabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "true"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/gamemode"
  },
  "WPFToggleLongPaths": {
    "Content": "Enable Long Paths",
    "Description": "Toggles support for file paths longer than 260 characters in Explorer.",
    "category": "Customize Preferences",
    "panel": "2",
    "Type": "Toggle",
    "registry": [
      {
        "Path": "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\FileSystem",
        "Name": "LongPathsEnabled",
        "Value": "1",
        "Type": "DWord",
        "OriginalValue": "0",
        "DefaultState": "false"
      }
    ],
    "link": "https://winutil.christitus.com/code-reference/tweaks/customize-preferences/longpaths"
  },
  "WPFOOSUbutton": {
    "Content": "O&O ShutUp10++ - Run",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "Type": "Button",
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/oosubutton"
  },
  "WPFchangedns": {
    "Content": "DNS - Set to:",
    "category": "z__Advanced Tweaks - CAUTION",
    "panel": "1",
    "Type": "Combobox",
    "ComboItems": "Default DHCP Fastest Google Cloudflare Cloudflare_Malware Cloudflare_Malware_Adult Open_DNS Quad9 AdGuard_Ads_Trackers AdGuard_Ads_Trackers_Malware_Adult",
    "link": "https://winutil.christitus.com/code-reference/tweaks/z--advanced-tweaks---caution/changedns"
  },
  "WPFAddUltPerf": {
    "Content": "Ultimate Performance Profile - Enable",
    "category": "Performance Plans - NOT FOR LAPTOPS",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "link": "https://winutil.christitus.com/code-reference/tweaks/performance-plans---not-for-laptops/addultperf"
  },
  "WPFRemoveUltPerf": {
    "Content": "Ultimate Performance Profile - Disable",
    "category": "Performance Plans - NOT FOR LAPTOPS",
    "panel": "2",
    "Type": "Button",
    "ButtonWidth": "300",
    "link": "https://winutil.christitus.com/code-reference/tweaks/performance-plans---not-for-laptops/removeultperf"
  }
}
'@ | ConvertFrom-Json
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
