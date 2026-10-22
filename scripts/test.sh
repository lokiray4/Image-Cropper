#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/scripts/common.sh"
require_macos
mkdir -p "$ROOT/.build"
SCRATCH="$(mktemp -d "$ROOT/.build/tests.XXXXXX")"
trap 'rm -rf "$SCRATCH"' EXIT
configure_swift "$SCRATCH"
xcrun swiftc -swift-version 5 -target "$(uname -m)-apple-macosx12.0" \
    ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} -module-cache-path "$ROOT/.build/cache-$(uname -m)" \
    "$ROOT/Sources/CropEngine.swift" "$ROOT/Tests/CropTests.swift" -o "$SCRATCH/CropTests"
"$SCRATCH/CropTests"
