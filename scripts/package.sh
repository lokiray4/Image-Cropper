#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
bash "$ROOT/scripts/build.sh" "$ROOT/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
ARCHIVE="$ROOT/dist/image-cropper-mac-v${VERSION}.zip"
ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/图片随手裁.app" "$ARCHIVE"
(cd "$ROOT/dist" && shasum -a 256 "$(basename "$ARCHIVE")" > "$(basename "$ARCHIVE").sha256")
echo "已打包：$ARCHIVE"
