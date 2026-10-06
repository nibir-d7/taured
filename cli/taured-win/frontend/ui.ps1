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
            Background = "#141B1E"; Panel = "#232A2D"; Border = "#343D40"
            Foreground = "#DADADA"; Muted = "#B3B9B8"; Accent = "#8CCF7E"
            AccentHover = "#A0DC91"; Selected = "#29372E"
        }
    }

    return @{
        Background = "#141B1E"; Panel = "#232A2D"; Border = "#343D40"
        Foreground = "#DADADA"; Muted = "#B3B9B8"; Accent = "#8CCF7E"
        AccentHover = "#A0DC91"; Selected = "#29372E"
    }
}

$script:tauredIconBase64 = '#{tauredIconBase64}'

function Get-tauredBrandImage {
    if ([string]::IsNullOrWhiteSpace($script:tauredIconBase64) -or $script:tauredIconBase64 -eq '#{tauredIconBase64}') {
        return $null
    }

    $bytes = [Convert]::FromBase64String($script:tauredIconBase64)
    $stream = [System.IO.MemoryStream]::new($bytes)
    try {
        $image = [System.Windows.Media.Imaging.BitmapImage]::new()
        $image.BeginInit()
        $image.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $image.StreamSource = $stream
        $image.EndInit()
        $image.Freeze()
        return $image
    }
    finally {
        $stream.Dispose()
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
        $button.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Palette.Background)
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
    $window.Title = "Taured - Windows Utility"
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
    $window.Icon = Get-tauredBrandImage

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
    $mark = New-Object System.Windows.Controls.Image
    $mark.Width = 30
    $mark.Height = 30
    $mark.Margin = New-Object System.Windows.Thickness(0, 0, 10, 0)
    $mark.Source = Get-tauredBrandImage
    $mark.Stretch = [System.Windows.Media.Stretch]::Uniform
    $brand.Children.Add($mark) | Out-Null
    $titleStack = New-Object System.Windows.Controls.StackPanel
    $titleStack.VerticalAlignment = "Center"
    $titleStack.Children.Add((New-tauredTextBlock -Text "Taured" -Color $Palette.Accent -Size 20 -Bold)) | Out-Null
    $titleStack.Children.Add((New-tauredTextBlock -Text "Windows Utility" -Color $Palette.Muted -Size 11)) | Out-Null
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
    $footer.ColumnDefinitions.Add((New-tauredColumn -Star))
    $status = New-tauredTextBlock -Text "Ready" -Color $Palette.Muted -Size 11
    $status.VerticalAlignment = "Center"
    [System.Windows.Controls.Grid]::SetColumn($status, 0) | Out-Null
    $footer.Children.Add($status) | Out-Null
    $credit = New-tauredTextBlock -Text "Inspired by Chris Titus Tech" -Color $Palette.Muted -Size 11
    $credit.VerticalAlignment = "Center"
    $credit.HorizontalAlignment = "Right"
    [System.Windows.Controls.Grid]::SetColumn($credit, 1) | Out-Null
    $footer.Children.Add($credit) | Out-Null
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
