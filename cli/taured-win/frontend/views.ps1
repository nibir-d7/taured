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
    $search.Tag = $Ui
    $search.Add_TextChanged({
            param($sender, $eventArgs)
            $searchUi = $sender.Tag
            $searchUi.Search = $sender.Text
            Add-tauredInstallList -Ui $searchUi -List $searchUi.Rows["list"]
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
    $list.Tag = $Ui
    $list.Add_SelectionChanged({
            param($sender, $eventArgs)
            try {
                if ($sender.SelectedItem) { Update-tauredDetail -Ui $sender.Tag -Entry $sender.SelectedItem }
            }
            catch {
                Write-tauredLog "Could not show app details: $($_.Exception.Message)" "ERROR"
            }
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
            Kind = "app"
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

    $spacer = New-Object System.Windows.Controls.Border
    $spacer.Height = 10
    $panel.Children.Add($spacer) | Out-Null

    $description = New-tauredTextBlock -Text $Entry.Description -Color $Ui.Palette.Foreground -Size 12.5
    $description.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $panel.Children.Add($description) | Out-Null

    $spacer2 = New-Object System.Windows.Controls.Border
    $spacer2.Height = 12
    $panel.Children.Add($spacer2) | Out-Null

    $detailMeta = if ($Entry.Kind -eq "tweak") { "Changes: $($Entry.Source)" } else { "Installed with $($Entry.Source)" }
    $panel.Children.Add((New-tauredTextBlock -Text $detailMeta -Color $Ui.Palette.Muted -Size 11)) | Out-Null

    $toggle = New-Object System.Windows.Controls.CheckBox
    $isTweak = $Entry.Kind -eq "tweak"
    $toggle.Content = if ($isTweak) { "Apply this tweak" } else { "Include in this run" }
    $toggle.Margin = New-Object System.Windows.Thickness(0, 14, 0, 0)
    $toggle.IsChecked = if ($isTweak) { $Ui.SelectedTweaks[$Entry.Id] } else { $Ui.SelectedApps[$Entry.Id] }
    $toggle.Tag = @{ Ui = $Ui; EntryId = $Entry.Id; Kind = if ($isTweak) { "tweak" } else { "app" } }
    $toggle.Add_Click({
            param($sender, $eventArgs)
            $toggleState = $sender.Tag
            if ($toggleState.Kind -eq "tweak") {
                $toggleState.Ui.SelectedTweaks[$toggleState.EntryId] = [bool]$sender.IsChecked
                foreach ($item in $toggleState.Ui.Rows["tweaksList"].ItemsSource) {
                    if ($item.Id -eq $toggleState.EntryId) { $item.Selected = [bool]$sender.IsChecked }
                }
                $toggleState.Ui.Rows["tweaksList"].Items.Refresh()
            }
            else {
                $toggleState.Ui.SelectedApps[$toggleState.EntryId] = [bool]$sender.IsChecked
                Add-tauredInstallList -Ui $toggleState.Ui -List $toggleState.Ui.Rows["list"]
            }
        })
    $panel.Children.Add($toggle) | Out-Null

    if ($Entry.Link) {
        $link = New-Object System.Windows.Controls.TextBlock
        $link.Text = $Entry.Link
        $link.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($Ui.Palette.Accent)
        $link.FontSize = 11.5
        $link.Margin = New-Object System.Windows.Thickness(0, 12, 0, 0)
        $link.TextDecorations = "Underline"
        $link.Tag = $Entry.Link
        $link.Add_MouseLeftButtonUp({
                param($sender, $eventArgs)
                Start-Process $sender.Tag
            })
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
    $list.Tag = $Ui
    $list.Add_SelectionChanged({
            param($sender, $eventArgs)
            try {
                if ($sender.SelectedItem) {
                    $uiScope = $sender.Tag
                    $entry = $sender.SelectedItem
                    $tweak = $uiScope.Configs.tweaks.$($entry.Id)
                    Update-tauredDetail -Ui $uiScope -Entry ([pscustomobject]@{
                            Id          = $entry.Id
                            Kind        = "tweak"
                            Name        = $entry.Name
                            Category    = $tweak.category
                            Description = $tweak.Description
                            Source      = (Format-tauredTweakSummary -Tweak $tweak)
                            Link        = $null
                        })
                }
            }
            catch {
                Write-tauredLog ("Could not show tweak details: " + ($_ | Out-String -Width 240).Trim()) "ERROR"
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
            $run.Tag = @{ Ui = $uiScope; FeatureId = $featureId }
            $run.Add_Click({
                    param($sender, $eventArgs)
                    $runState = $sender.Tag
                    $log = @((New-tauredRestorePoint))
                    $log += Invoke-tauredFeature -Feature $runState.Ui.Configs.feature.$($runState.FeatureId)
                    Show-tauredLog -Ui $runState.Ui -Lines $log
                })
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
        })
    $panel.Children.Add($logButton) | Out-Null

    $Content.Children.Add($panel) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($panel, 0) | Out-Null

    $about = New-tauredCard -Palette $Ui.Palette
    $about.Margin = New-Object System.Windows.Thickness(18, 0, 0, 0)
    $aboutStack = New-Object System.Windows.Controls.StackPanel
    $aboutStack.Children.Add((New-tauredTextBlock -Text "taured" -Color $Ui.Palette.Accent -Size 16 -Bold)) | Out-Null
    $aboutStack.Children.Add((New-tauredTextBlock -Text "Free, open, no login." -Color $Ui.Palette.Muted -Size 12)) | Out-Null
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
