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
    $close.Tag = $window
    $close.Add_Click({ param($sender, $eventArgs) $sender.Tag.Close() })
    $stack.Children.Add($close) | Out-Null

    $card.Child = $stack
    $window.Content = $card
    $window.ShowDialog() | Out-Null
}
