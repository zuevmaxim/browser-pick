#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOSITORY_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_BUNDLE="${1:-${REPOSITORY_ROOT}/.build/BrowserPick.app}"
EXECUTABLE="${APP_BUNDLE}/Contents/MacOS/BrowserPick"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"
EXPECTED_BUNDLE_ID="com.zuevmaxim.BrowserPick"
PLIST_BUDDY="/usr/libexec/PlistBuddy"

[[ -d "${APP_BUNDLE}" && -x "${EXECUTABLE}" && -f "${INFO_PLIST}" ]] || {
    echo "Invalid BrowserPick bundle: ${APP_BUNDLE}" >&2
    exit 1
}

BUNDLE_ID="$("${PLIST_BUDDY}" -c "Print :CFBundleIdentifier" "${INFO_PLIST}")"
[[ "${BUNDLE_ID}" == "${EXPECTED_BUNDLE_ID}" ]] || {
    echo "Unexpected bundle identifier: ${BUNDLE_ID}" >&2
    exit 1
}

if "${PLIST_BUDDY}" -c "Print :NSAppTransportSecurity:NSAllowsArbitraryLoads" "${INFO_PLIST}" >/dev/null 2>&1; then
    echo "NSAllowsArbitraryLoads must not be present." >&2
    exit 1
fi

if codesign -d --entitlements :- "${APP_BUNDLE}" 2>&1 | rg -q 'com\.apple\.security\.network\.(client|server)'; then
    echo "Network entitlements must not be present." >&2
    exit 1
fi

UNEXPECTED_LIBRARIES="$(otool -L "${EXECUTABLE}" | tail -n +2 | awk '{print $1}' | rg -v '^(/System/Library/|/usr/lib/)' || true)"
if [[ -n "${UNEXPECTED_LIBRARIES}" ]]; then
    echo "Unexpected linked libraries:" >&2
    echo "${UNEXPECTED_LIBRARIES}" >&2
    exit 1
fi

ENDPOINTS="$(strings "${EXECUTABLE}" | rg -o 'https?://[^[:space:]"<>]+' | sort -u || true)"
UNEXPECTED_ENDPOINTS="$(printf '%s\n' "${ENDPOINTS}" | rg -v '^(https://example\.com|https://github\.com/cvladan/browser-pick)$' || true)"
if [[ -n "${UNEXPECTED_ENDPOINTS}" ]]; then
    echo "Unexpected embedded endpoints:" >&2
    echo "${UNEXPECTED_ENDPOINTS}" >&2
    exit 1
fi

echo "Bundle inspection passed."
if [[ -n "${ENDPOINTS}" ]]; then
    echo "Allowlisted embedded endpoints:"
    echo "${ENDPOINTS}"
fi
