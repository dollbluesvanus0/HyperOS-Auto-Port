#!/usr/bin/env bash
set -euo pipefail
STOCK_URL="$1"
DONOR_URL="$2"
WORKDIR="$3"

mkdir -p "$WORKDIR/stock" "$WORKDIR/donor" "$WORKDIR/tmp"

cd "$WORKDIR"
# Download zips
curl -L -o stock.zip "$STOCK_URL"
curl -L -o donor.zip "$DONOR_URL"

# Unzip
unzip -q stock.zip -d stock
unzip -q donor.zip -d donor

# Find payload.bin in both (if present)
if [ -f stock/payload.bin ]; then
  mkdir -p stock/payload_extracted
  python3 tools/payload_dumper/payload_dumper.py -i stock/payload.bin -o stock/payload_extracted
fi

if [ -f donor/payload.bin ]; then
  mkdir -p donor/payload_extracted
  python3 tools/payload_dumper/payload_dumper.py -i donor/payload.bin -o donor/payload_extracted
fi

# Move expected images to top-level for convenience
# stock: product.img, system_ext.img
# donor: mi_ext.img, system.img, system_ext.img, product.img
for f in stock/payload_extracted/*.img; do
  cp -v "$f" stock/ || true
done
for f in donor/payload_extracted/*.img; do
  cp -v "$f" donor/ || true
done
