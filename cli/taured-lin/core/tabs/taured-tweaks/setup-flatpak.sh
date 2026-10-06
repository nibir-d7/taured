#!/usr/bin/env bash
set -euo pipefail

if command -v apt-get >/dev/null; then sudo apt install -y flatpak; elif command -v dnf >/dev/null; then sudo dnf install -y flatpak; else sudo pacman -S --noconfirm flatpak; fi
flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
