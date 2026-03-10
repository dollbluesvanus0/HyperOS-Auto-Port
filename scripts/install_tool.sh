#!/usr/bin/env bash
set -euo pipefail

# Ensure universe repo
sudo add-apt-repository -y universe
sudo apt-get update

# Install packaged tools
sudo apt-get install -y python3 python3-pip unzip p7zip-full android-sdk-libsparse-utils libarchive-tools e2fsprogs

# Snap fallback and aliases
if ! command -v simg2img >/dev/null 2>&1; then
  sudo snap install android-platform-tools --classic || true
  sudo snap alias android-platform-tools.simg2img simg2img || true
  sudo snap alias android-platform-tools.img2simg img2simg || true
fi

# Build fallback
if ! command -v simg2img >/dev/null 2>&1; then
  git clone https://github.com/anestisb/android-simg2img.git /tmp/android-simg2img || true
  sudo apt-get install -y build-essential zlib1g-dev || true
  (cd /tmp/android-simg2img && make) || true
  sudo cp -f /tmp/android-simg2img/simg2img /usr/local/bin/ || true
fi

# payload_dumper (python)
TOOLS_DIR="$(pwd)/tools"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"
if [ ! -d payload_dumper ]; then
  git clone https://github.com/vm03/payload_dumper.git payload_dumper || true
fi
pip3 install --user protobuf || true
echo "PATH=$PATH:$TOOLS_DIR/payload_dumper" >> "$GITHUB_ENV" || true
