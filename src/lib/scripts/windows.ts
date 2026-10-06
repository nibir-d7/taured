import type { App } from "@/lib/types";

export function buildWindowsScript(apps: App[]): string {
  const lines: string[] = [];
  lines.push("# taured.space - Windows setup script");
  lines.push("# Review every line before running. Open PowerShell as Administrator.");
  lines.push("# Create a restore point first: Checkpoint-Computer -Description 'Before taured' -RestorePointType MODIFY_SETTINGS");
  lines.push("");
  lines.push("$ErrorActionPreference = 'Continue'");
  lines.push("");
  lines.push("if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {");
  lines.push("    Write-Host 'winget not found, installing App Installer...' -ForegroundColor Yellow");
  lines.push("    Start-Process 'https://get.microsoft.com/winget'");
  lines.push("}");
  lines.push("");
  const wingetAvailable = apps.some((app) => app.win_winget);

  if (wingetAvailable) {
    lines.push("if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {");
    lines.push("    Write-Host 'winget is required for these apps. Install it, then re-run this script.' -ForegroundColor Red");
    lines.push("    exit 1");
    lines.push("}");
    lines.push("");
  }

  lines.push("$installed = 0");
  lines.push("$failed = 0");
  lines.push("");

  for (const app of apps) {
    lines.push(`# ${app.name}`);
    if (app.win_winget) {
      lines.push(`winget install --id ${app.win_winget} -e --source winget --accept-package-agreements --accept-source-agreements`);
      if (app.win_choco) lines.push(`# Chocolatey fallback: choco install ${app.win_choco} -y`);
    } else if (app.win_choco) {
      lines.push(`choco install ${app.win_choco} -y`);
    } else {
      lines.push("# No Windows installer mapped yet - add one in the admin panel");
      continue;
    }
    lines.push(`if ($LASTEXITCODE -eq 0) { $installed++ } else { $failed++; Write-Host "Failed: ${app.name}" -ForegroundColor Red }`);
    lines.push("");
  }

  lines.push('Write-Host ""');
  lines.push('Write-Host "Installed: $installed   Failed: $failed" -ForegroundColor Cyan');
  if (wingetAvailable && apps.some((app) => app.win_choco)) {
    lines.push('Write-Host "Anything missing? The Chocolatey fallback commands are listed above each install." -ForegroundColor DarkGray');
  }
  lines.push('Write-Host "Restart is recommended."');
  return lines.join("\n");
}