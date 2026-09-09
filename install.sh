#!/usr/bin/env bash
# Build, install into a Launch-Services-indexed user directory, and launch.
# Usage: ./install.sh [debug|release] [--replace]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""
REPLACE=false
APP_NAME="BrowserPick"
EXPECTED_BUNDLE_ID="com.zuevmaxim.BrowserPick"
INSTALL_DIR="${INSTALL_DIR:-${HOME}/Applications}"
SOURCE_APP="${SCRIPT_DIR}/.build/${APP_NAME}.app"
INSTALLED_APP="${INSTALL_DIR}/${APP_NAME}.app"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

for argument in "$@"; do
    case "${argument}" in
        debug|release)
            if [[ -n "${CONFIG}" ]]; then
                echo "Specify exactly one build configuration." >&2
                exit 2
            fi
            CONFIG="${argument}"
            ;;
        --replace)
            if [[ "${REPLACE}" == true ]]; then
                echo "--replace may only be specified once." >&2
                exit 2
            fi
            REPLACE=true
            ;;
        *)
            echo "Usage: $0 [debug|release] [--replace]" >&2
            exit 2
            ;;
    esac
done
CONFIG="${CONFIG:-debug}"

if [[ "${INSTALL_DIR}" != /* || "${INSTALL_DIR}" == "/" ]]; then
    echo "INSTALL_DIR must be an absolute directory other than /." >&2
    exit 2
fi

"${SCRIPT_DIR}/build.sh" "${CONFIG}"

if [[ -e "${INSTALLED_APP}" ]]; then
    if [[ "${REPLACE}" != true ]]; then
        echo "Refusing to replace ${INSTALLED_APP}; pass --replace explicitly." >&2
        exit 1
    fi

    EXISTING_BUNDLE_ID="$("${PLIST_BUDDY}" -c "Print :CFBundleIdentifier" "${INSTALLED_APP}/Contents/Info.plist" 2>/dev/null || true)"
    if [[ "${EXISTING_BUNDLE_ID}" != "${EXPECTED_BUNDLE_ID}" ]]; then
        echo "Refusing to remove ${INSTALLED_APP}: bundle identifier does not match ${EXPECTED_BUNDLE_ID}." >&2
        exit 1
    fi

    echo "==> Stopping ${INSTALLED_APP}"
    while IFS= read -r process_id; do
        [[ -n "${process_id}" ]] && kill -TERM "${process_id}"
    done < <(pgrep -f -x "${INSTALLED_APP}/Contents/MacOS/${APP_NAME}" || true)

    echo "==> Replacing ${INSTALLED_APP}"
    rm -rf "${INSTALLED_APP}"
fi

mkdir -p "${INSTALL_DIR}"
echo "==> Installing to ${INSTALLED_APP}"
ditto "${SOURCE_APP}" "${INSTALLED_APP}"

echo "==> Launching"
open "${INSTALLED_APP}"

echo
echo "Done. BrowserPick is installed at ${INSTALLED_APP} and running."
