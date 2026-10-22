#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
require_macos
DEST="${1:-$ROOT/dist}"
mkdir -p "$DEST" "$ROOT/.build"
DEST="$(cd "$DEST" && pwd)"
SCRATCH="$(mktemp -d "$ROOT/.build/compile.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
configure_swift "$SCRATCH"
for ARCH in arm64 x86_64; do
    xcrun swiftc -swift-version 5 -O -target "${ARCH}-apple-macosx12.0" \
        ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} -module-cache-path "$ROOT/.build/cache-$ARCH" \
        "$ROOT/Sources/CropEngine.swift" "$ROOT/Sources/main.swift" -o "$SCRATCH/ImageCropper-$ARCH"
done
APP="$DEST/图片随手裁.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
xcrun lipo -create "$SCRATCH/ImageCropper-arm64" "$SCRATCH/ImageCropper-x86_64" -output "$APP/Contents/MacOS/ImageCropper"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
xcrun lipo "$APP/Contents/MacOS/ImageCropper" -verify_arch arm64 x86_64
echo "已构建：$APP"
