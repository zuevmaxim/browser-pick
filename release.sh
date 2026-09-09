#!/usr/bin/env bash
# Build a local release archive and print its checksum. This script does not
# publish, tag, commit, push, or modify any Homebrew tap.
#
# Usage:
#   ./release.sh           # package the version currently in Info.plist
#   ./release.sh 0.1.0     # also assert that Info.plist contains this version
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="BrowserPick"
APP_BUNDLE="${SCRIPT_DIR}/.build/${APP_NAME}.app"
INFO_PLIST="${SCRIPT_DIR}/Resources/Info.plist"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

[[ -x "${PLIST_BUDDY}" ]] || { echo "PlistBuddy not found at ${PLIST_BUDDY}" >&2; exit 1; }

if [[ $# -gt 1 ]]; then
    echo "Usage: $0 [X.Y.Z]" >&2
    exit 2
fi
VERSION="$("${PLIST_BUDDY}" -c "Print :CFBundleShortVersionString" "${INFO_PLIST}")"
BUILD_VERSION="$("${PLIST_BUDDY}" -c "Print :CFBundleVersion" "${INFO_PLIST}")"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "CFBundleShortVersionString '${VERSION}' is not a valid X.Y.Z version." >&2
    exit 1
fi
if [[ "${BUILD_VERSION}" != "${VERSION}" ]]; then
    echo "CFBundleVersion '${BUILD_VERSION}' does not match '${VERSION}'." >&2
    exit 1
fi
if [[ $# -eq 1 ]]; then
    if [[ ! "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Version '$1' is not valid; expected X.Y.Z." >&2
        exit 2
    fi
    if [[ "$1" != "${VERSION}" ]]; then
        echo "Requested version '$1' does not match Info.plist version '${VERSION}'." >&2
        exit 1
    fi
fi
ZIP_PATH="${SCRIPT_DIR}/.build/${APP_NAME}-${VERSION}.zip"

echo "==> Building release"
"${SCRIPT_DIR}/build.sh" release

echo "==> Zipping ${APP_BUNDLE} -> ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

SHA256="$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')"
SIZE="$(du -h "${ZIP_PATH}" | awk '{print $1}')"
echo "==> ${ZIP_PATH}  (${SIZE}, sha256: ${SHA256})"
echo "Local package complete. Publishing remains disabled."
