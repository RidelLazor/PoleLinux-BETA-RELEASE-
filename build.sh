#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="polelinux-arch-builder"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Generating Plymouth animation assets..."
python3 "$SCRIPT_DIR/plymouth-theme/generate-assets.py"

echo "==> Building Docker builder image..."
docker build -t "$IMAGE_NAME" "$SCRIPT_DIR"

echo "==> Running ISO build..."
docker run --rm --privileged --network=host \
  -v "$SCRIPT_DIR:/build" \
  -v /var/cache/pacman/pkg:/var/cache/pacman/pkg:ro \
  "$IMAGE_NAME" \
  bash /build/scripts/build-iso.sh

echo "==> Build complete!"
ls -lh "$SCRIPT_DIR/images/"*.iso 2>/dev/null || echo "ISO not found in images/"
