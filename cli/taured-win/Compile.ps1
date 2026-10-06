param (
    [switch]$Run,
    [switch]$SelfTest
)

$root = $PSScriptRoot
$OFS = "`r`n"

$sync = @{}
$sync.configs = @{}

$script = (Get-Content -Path (Join-Path $root "scripts\start.ps1")) -replace '#{replaceme}', (Get-Date -Format 'yy.MM.dd')
$isLocalCompile = -not [string]::Equals($env:GITHUB_ACTIONS, "true", [StringComparison]::OrdinalIgnoreCase)
$script = $script -replace '#{islocalcompile}', $isLocalCompile.ToString().ToLowerInvariant()

Get-ChildItem (Join-Path $root "frontend") -File | Sort-Object Name | ForEach-Object {
    $script += Get-Content -Path $_.FullName -Raw
}

Get-ChildItem (Join-Path $root "config") | ForEach-Object {
    $obj = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
    $json = $obj | ConvertTo-Json -Depth 10
    $sync.configs[$_.BaseName] = $obj
    $script += "`$sync.configs.$($_.BaseName) = @'`r`n$json`r`n'@ | ConvertFrom-Json"
}

$script += Get-Content -Path (Join-Path $root "scripts\main.ps1") -Raw

Set-Content -Path (Join-Path $root "taured.ps1") -Value $script

if ($SelfTest) {
    Write-Host "Running self test..."
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '$root\taured.ps1' -SelfTest"
}

if ($Run) {
    & (Join-Path $root "taured.ps1")
}