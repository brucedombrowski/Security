#!/bin/bash
#
# Web Browsers Collector
#
# Purpose: Collect installed web browser versions
# NIST Control: CM-8 (System Component Inventory)
#
# Functions:
#   collect_browsers() - Collect web browser versions
#
# Dependencies: output.sh (for output function), detect.sh (for find_macos_ide_version, find_linux_browser_version)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect web browser versions
# Usage: collect_browsers
collect_browsers() {
    output "Web Browsers:"
    output "-------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        _collect_browsers_macos
    elif [[ "$(uname)" == "Linux" ]]; then
        _collect_browsers_linux
    fi

    output ""
}

# Internal: Collect browsers on macOS
_collect_browsers_macos() {
    local ver

    # Chrome
    local chrome_paths=(
        "/Applications/Google Chrome.app"
        "$HOME/Applications/Google Chrome.app"
        "/Applications/Chromium.app"
        "$HOME/Applications/Chromium.app"
    )
    ver=$(find_macos_ide_version "${chrome_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Chrome: $ver"
    else
        output "  Chrome: not installed"
    fi

    # Firefox
    local firefox_paths=(
        "/Applications/Firefox.app"
        "$HOME/Applications/Firefox.app"
        "/Applications/Firefox Developer Edition.app"
        "/Applications/Firefox Nightly.app"
    )
    ver=$(find_macos_ide_version "${firefox_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Firefox: $ver"
    else
        output "  Firefox: not installed"
    fi

    # Safari (always installed on macOS)
    local safari_ver
    safari_ver=$(defaults read "/Applications/Safari.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
    output "  Safari: $safari_ver"

    # Microsoft Edge
    local edge_paths=(
        "/Applications/Microsoft Edge.app"
        "$HOME/Applications/Microsoft Edge.app"
    )
    ver=$(find_macos_ide_version "${edge_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Edge: $ver"
    else
        output "  Edge: not installed"
    fi

    # Brave
    local brave_paths=(
        "/Applications/Brave Browser.app"
        "$HOME/Applications/Brave Browser.app"
    )
    ver=$(find_macos_ide_version "${brave_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Brave: $ver"
    else
        output "  Brave: not installed"
    fi

    # Opera
    local opera_paths=(
        "/Applications/Opera.app"
        "$HOME/Applications/Opera.app"
    )
    ver=$(find_macos_ide_version "${opera_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Opera: $ver"
    else
        output "  Opera: not installed"
    fi

    # Vivaldi
    local vivaldi_paths=(
        "/Applications/Vivaldi.app"
        "$HOME/Applications/Vivaldi.app"
    )
    ver=$(find_macos_ide_version "${vivaldi_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Vivaldi: $ver"
    else
        output "  Vivaldi: not installed"
    fi
}

# Internal: Collect browsers on Linux
_collect_browsers_linux() {
    local ver

    # Chrome - check command, snap, flatpak, package managers
    ver=$(find_linux_browser_version "google-chrome" "chromium" "com.google.Chrome" "google-chrome" "google-chrome" || true)
    if [ -z "$ver" ]; then
        # Also try chromium variants
        ver=$(find_linux_browser_version "chromium" "chromium" "" "chromium" "chromium" || true)
        if [ -z "$ver" ]; then
            ver=$(find_linux_browser_version "chromium-browser" "" "" "" "" || true)
        fi
    fi
    if [ -n "$ver" ]; then
        output "  Chrome/Chromium: $ver"
    else
        output "  Chrome/Chromium: not installed"
    fi

    # Firefox
    ver=$(find_linux_browser_version "firefox" "firefox" "org.mozilla.firefox" "firefox" "firefox" || true)
    if [ -n "$ver" ]; then
        output "  Firefox: $ver"
    else
        output "  Firefox: not installed"
    fi

    # Edge
    ver=$(find_linux_browser_version "microsoft-edge" "" "" "microsoft-edge" "microsoft-edge" || true)
    if [ -z "$ver" ]; then
        ver=$(find_linux_browser_version "microsoft-edge-stable" "" "" "" "" || true)
    fi
    if [ -n "$ver" ]; then
        output "  Edge: $ver"
    else
        output "  Edge: not installed"
    fi

    # Brave
    ver=$(find_linux_browser_version "brave-browser" "brave" "com.brave.Browser" "brave-browser" "brave-browser" || true)
    if [ -n "$ver" ]; then
        output "  Brave: $ver"
    else
        output "  Brave: not installed"
    fi

    # Opera
    ver=$(find_linux_browser_version "opera" "opera" "com.opera.Opera" "opera" "opera" || true)
    if [ -n "$ver" ]; then
        output "  Opera: $ver"
    else
        output "  Opera: not installed"
    fi

    # Vivaldi
    ver=$(find_linux_browser_version "vivaldi" "vivaldi" "com.vivaldi.Vivaldi" "vivaldi" "vivaldi" || true)
    if [ -z "$ver" ]; then
        ver=$(find_linux_browser_version "vivaldi-stable" "" "" "" "" || true)
    fi
    if [ -n "$ver" ]; then
        output "  Vivaldi: $ver"
    else
        output "  Vivaldi: not installed"
    fi
}
