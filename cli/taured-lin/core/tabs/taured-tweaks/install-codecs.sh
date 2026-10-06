#!/usr/bin/env bash
set -euo pipefail

if command -v apt-get >/dev/null; then sudo apt install -y ubuntu-restricted-extras ffmpeg; elif command -v dnf >/dev/null; then sudo dnf install -y ffmpeg gstreamer1-plugins-good gstreamer1-plugins-bad; else sudo pacman -S --noconfirm ffmpeg gst-plugins-good gst-plugins-bad; fi
