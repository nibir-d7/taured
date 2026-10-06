#!/usr/bin/env bash
set -euo pipefail

echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system
