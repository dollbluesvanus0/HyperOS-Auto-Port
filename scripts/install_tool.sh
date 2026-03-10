#!/usr/bin/env bash
set -euo pipefail

# Ensure universe repo and update
sudo apt-get update
sudo apt-get install -y software-properties-common || true
sudo add-apt-repository -y universe || true
sudo apt-get update

# Install common tools and correct packages
sudo apt-get install -y \
  python3 python3-pip unzip p7zip-full \
  android-sdk-libsparse-utils libarchive-tools e2fsprogs git build-essential zlib1g-dev || true

# Verify simg2img and bsdtar presence
if ! command -v simg2img >/dev/null 2>&1; then
  echo "simg2img not found via apt, trying snap fallback..."
  sudo snap install android-platform-tools --classic || true
  # create aliases if snap provides binaries under different names
  sudo snap alias android-platform-tools.simg2img simg2img || true
  sudo snap alias android-platform-tools.img2simg img2simg || true
fi

# Final fallback: build simg2img from source if still missing
if ! command -v simg2img >/dev/null 2>&1; then
  echo "Building simg2img from source..."
  TMPDIR=$(mktemp -d)
  git clone https://github.com/anestisb/android-simg2img.git "$TMPDIR/android-simg2img" || true
  if [ -f "$TMPDIR/android-simg2img/Makefile" ]; then
    (cd "$TMPDIR/android-simg2img" && make) || true
    sudo cp -f "$TMPDIR/android-simg2img/simg2img" /usr/local/bin/ || true
    sudo cp -f "$TMPDIR/android-simg2img/img2simg" /usr/local/bin/ || true
  fi
  rm -rf "$TMPDIR"
fi

# Verify bsdtar (libarchive-tools)
if ! command -v bsdtar >/dev/null 2>&1; then
  echo "bsdtar not found; libarchive-tools may be missing. Attempting apt reinstall..."
  sudo apt-get install -y libarchive-tools || true
fi

# Install payload_dumper (python implementation) into tools/
TOOLS_DIR="$(pwd)/tools"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"
if [ ! -d payload_dumper ]; then
  git clone https://github.com/vm03/payload_dumper.git payload_dumper || true
fi
pip3 install --user protobuf || true

# Export PATH for workflow steps (GitHub Actions will pick up $GITHUB_ENV)
echo "PATH=$PATH:$TOOLS_DIR/payload_dumper" >> "$GITHUB_ENV" || true

# Final checks
echo "=== Tool check ==="
command -v simg2img || echo "simg2img: missing"
simg2img --help 2>/dev/null || true
command -v img2simg || echo "img2simg: missing"
command -v bsdtar || echo "bsdtar: missing"
