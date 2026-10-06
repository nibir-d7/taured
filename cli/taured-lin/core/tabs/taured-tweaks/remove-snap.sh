#!/usr/bin/env bash
set -euo pipefail

sudo apt purge -y snapd || sudo dnf remove -y snapd || sudo pacman -Rns --noconfirm snapd || true
rm -rf ~/snap /var/snap /var/lib/snapd
