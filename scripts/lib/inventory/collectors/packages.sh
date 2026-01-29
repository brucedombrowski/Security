#!/bin/bash
#
# Package Manager Collector
#
# Purpose: Collect installed software packages (Homebrew, dpkg, rpm)
# NIST Control: CM-8 (System Component Inventory)
#
# Functions:
#   collect_packages() - Collect installed packages from system package managers
#
# Dependencies: output.sh (for output function)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect installed software packages
# Usage: collect_packages
collect_packages() {
    output "Installed Software Packages:"
    output "----------------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        # Homebrew packages
        if command -v brew >/dev/null 2>&1; then
            output "  Homebrew Packages:"
            brew list --versions 2>/dev/null | while read -r line; do
                output "    $line"
            done
            output ""
            output "  Homebrew Casks:"
            brew list --cask --versions 2>/dev/null | while read -r line; do
                output "    $line"
            done
        else
            output "  Homebrew: not installed"
        fi
        output ""

        # System applications (from /Applications)
        output "  Applications (/Applications):"
        for app in /Applications/*.app; do
            if [ -d "$app" ]; then
                local app_name version
                app_name=$(basename "$app" .app)
                # Try to get version from Info.plist
                version=$(defaults read "$app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
                output "    $app_name: $version"
            fi
        done

    elif [[ "$(uname)" == "Linux" ]]; then
        # Debian/Ubuntu
        if command -v dpkg >/dev/null 2>&1; then
            output "  Debian/Ubuntu Packages (dpkg):"
            while IFS= read -r line; do
                output "$line"
            done <<< "$(dpkg-query -W -f='    ${Package}: ${Version}\n' 2>/dev/null | head -100)"
            local pkg_count
            pkg_count=$(dpkg-query -W -f='${Package}\n' 2>/dev/null | wc -l)
            if [ "$pkg_count" -gt 100 ]; then
                output "    ... and $((pkg_count - 100)) more packages (total: $pkg_count)"
            fi

        # RHEL/CentOS/Fedora
        elif command -v rpm >/dev/null 2>&1; then
            output "  RPM Packages:"
            while IFS= read -r line; do
                output "$line"
            done <<< "$(rpm -qa --queryformat '    %{NAME}: %{VERSION}-%{RELEASE}\n' 2>/dev/null | sort | head -100)"
            local pkg_count
            pkg_count=$(rpm -qa 2>/dev/null | wc -l)
            if [ "$pkg_count" -gt 100 ]; then
                output "    ... and $((pkg_count - 100)) more packages (total: $pkg_count)"
            fi
        fi
    fi

    output ""
}
