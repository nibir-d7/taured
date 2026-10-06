#!/usr/bin/env bash
set -euo pipefail

gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"
