#!/usr/bin/env bash
set -euo pipefail
WORKDIR="$1"

# Remove large temporary files and caches
sudo rm -rf "$WORKDIR" || true
sudo apt-get clean || true
sudo rm -rf /var/lib/apt/lists/* || true

# Show disk usage after cleanup
df -h || true
