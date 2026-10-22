#!/bin/bash
# Shared helpers, sourced by the build and test entry points.

require_macos() {
    if [ "$(uname -s)" != Darwin ]; then
        echo "This project requires macOS and Apple Command Line Tools." >&2
        exit 1
    fi
    xcrun --find swiftc >/dev/null
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

configure_swift() {
    local scratch="$1"
    SWIFT_FLAGS=()
    local toolchain_include
    toolchain_include="$(dirname "$(xcrun --find swiftc)")/../include/swift"
    # Upgraded CLT installations can contain two SwiftBridging module maps.
    # A compiler-only VFS overlay hides the legacy map without editing the SDK.
    if [ -f "$toolchain_include/module.modulemap" ] && \
       [ -f "$toolchain_include/bridging.modulemap" ] && \
       grep -q 'module SwiftBridging' "$toolchain_include/module.modulemap" && \
       grep -q 'module SwiftBridging' "$toolchain_include/bridging.modulemap"; then
        toolchain_include="$(cd "$toolchain_include" && pwd)"
        echo '// Legacy duplicate hidden for this build.' > "$scratch/empty.modulemap"
        printf '{"version":0,"roots":[{"type":"file","name":"%s/module.modulemap","external-contents":"%s/empty.modulemap"}]}\n' \
            "$(json_escape "$toolchain_include")" "$(json_escape "$scratch")" > "$scratch/overlay.json"
        SWIFT_FLAGS=(-vfsoverlay "$scratch/overlay.json")
    fi
}
