#!/usr/bin/env bash
set -euo pipefail

# Install payload_dumper (python script) into tools/
TOOLS_DIR="$(pwd)/tools"
mkdir -p "$TOOLS_DIR"
cd "$TOOLS_DIR"

# Clone a payload dumper implementation (or pip install if available)
if [ ! -d payload_dumper ]; then
  git clone https://github.com/vm03/payload_dumper.git payload_dumper || true
fi

# Ensure python deps (if any)
pip3 install --user protobuf || true

# Add tools to PATH for the workflow steps
echo "export PATH=\$PATH:$TOOLS_DIR/payload_dumper" >> "$GITHUB_ENV" || true
