#!/usr/bin/env bash
# Build BrowserPick.app from SPM output + Info.plist.
# Usage: ./build.sh            (debug, ad-hoc signed)
#        ./build.sh release    (release, ad-hoc signed)
set -euo pipefail

if [[ $# -gt 1 || "${1:-debug}" != "debug" && "${1:-debug}" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${1:-debug}"
APP_NAME="BrowserPick"
BUILD_DIR="${SCRIPT_DIR}/.build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SWIFT_FLAGS=(-Xswiftc -warnings-as-errors)

echo "==> swift build (${CONFIG})"
if [[ "$CONFIG" == "release" ]]; then
    swift build --package-path "${SCRIPT_DIR}" -c release "${SWIFT_FLAGS[@]}"
    BIN_PATH="${BUILD_DIR}/release/${APP_NAME}"
else
    swift build --package-path "${SCRIPT_DIR}" "${SWIFT_FLAGS[@]}"
    BIN_PATH="${BUILD_DIR}/debug/${APP_NAME}"
fi

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${SCRIPT_DIR}/Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
printf "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "${APP_BUNDLE}"

echo ""
echo "Built: ${APP_BUNDLE}"
echo "Open with: open ${APP_BUNDLE}"
