import type { App } from "@/lib/types";

export function buildLinuxScript(apps: App[]): string {
  const lines: string[] = [];
  lines.push("#!/usr/bin/env bash");
  lines.push("# taured.space - Linux setup script");
  lines.push("# Review every line before running. Back up anything important first.");
  lines.push("set -uo pipefail");
  lines.push("");
  lines.push('if [ "$(id -u)" -ne 0 ]; then echo "taured: run with sudo: sudo bash $0"; exit 1; fi');
  lines.push("");
  lines.push("if command -v apt-get >/dev/null 2>&1; then PM=apt");
  lines.push("elif command -v dnf >/dev/null 2>&1; then PM=dnf");
  lines.push("elif command -v pacman >/dev/null 2>&1; then PM=pacman");
  lines.push("else echo 'taured: no supported package manager found (apt, dnf, pacman)'; exit 1; fi");
  lines.push('echo "taured: using $PM"');
  lines.push("");
  lines.push("installed=0");
  lines.push("failed=0");
  lines.push("");

  for (const app of apps) {
    lines.push(`# ${app.name}`);
    if (app.linux_flatpak) lines.push(`# flatpak: flatpak install -y ${app.linux_flatpak}`);
    if (app.linux_snap) lines.push(`# snap: sudo snap install ${app.linux_snap}`);
    const hasNative = app.linux_apt || app.linux_dnf || app.linux_pacman;
    if (!hasNative && !app.linux_flatpak && !app.linux_snap) {
      lines.push("# No Linux package mapped yet - add one in the admin panel");
      lines.push("");
      continue;
    }
    if (hasNative) {
      lines.push('case "$PM" in');
      if (app.linux_apt) lines.push(`  apt) DEBIAN_FRONTEND=noninteractive apt-get install -y ${app.linux_apt} ;;`);
      if (app.linux_dnf) lines.push(`  dnf) dnf install -y ${app.linux_dnf} ;;`);
      if (app.linux_pacman) lines.push(`  pacman) pacman -S --noconfirm ${app.linux_pacman} ;;`);
      lines.push("esac");
      lines.push('if [ $? -eq 0 ]; then installed=$((installed+1)); else failed=$((failed+1)); echo "Failed: ' + app.name + '" >&2; fi');
    }
    lines.push("");
  }

  lines.push('echo ""');
  lines.push('echo "taured: installed $installed, failed $failed"');
  lines.push('echo "Restart is recommended."');
  return lines.join("\n");
}