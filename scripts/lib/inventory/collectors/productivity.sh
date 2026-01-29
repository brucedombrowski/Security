#!/bin/bash
#
# Productivity Software Collector
#
# Purpose: Collect installed office and communication software versions
# NIST Control: CM-8 (System Component Inventory)
#
# Functions:
#   collect_productivity() - Collect productivity software versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool, detect_macos_app)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect productivity software versions
# Usage: collect_productivity
collect_productivity() {
    output "Productivity Software:"
    output "----------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        _collect_productivity_macos
    elif [[ "$(uname)" == "Linux" ]]; then
        _collect_productivity_linux
    fi

    output ""
}

# Internal: Collect productivity software on macOS
_collect_productivity_macos() {
    # Microsoft Office apps
    detect_macos_app "Microsoft Word" "/Applications/Microsoft Word.app"
    detect_macos_app "Microsoft Excel" "/Applications/Microsoft Excel.app"
    detect_macos_app "Microsoft PowerPoint" "/Applications/Microsoft PowerPoint.app"
    detect_macos_app "Microsoft Outlook" "/Applications/Microsoft Outlook.app"

    # Microsoft Teams (check multiple paths)
    if [ -d "/Applications/Microsoft Teams.app" ] || [ -d "/Applications/Microsoft Teams (work or school).app" ]; then
        local teams_ver
        teams_ver=$(defaults read "/Applications/Microsoft Teams.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || \
                    defaults read "/Applications/Microsoft Teams (work or school).app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
        output "  Microsoft Teams: $teams_ver"
    else
        output "  Microsoft Teams: not installed"
    fi

    # Apple iWork
    detect_macos_app "Apple Pages" "/Applications/Pages.app"
    detect_macos_app "Apple Numbers" "/Applications/Numbers.app"
    detect_macos_app "Apple Keynote" "/Applications/Keynote.app"

    # LibreOffice
    detect_macos_app "LibreOffice" "/Applications/LibreOffice.app"

    # Communication apps
    detect_macos_app "Slack" "/Applications/Slack.app"
    detect_macos_app "Cisco Webex" "/Applications/Webex.app"
    detect_macos_app "Discord" "/Applications/Discord.app"
    detect_macos_app "Skype" "/Applications/Skype.app"
}

# Internal: Collect productivity software on Linux
_collect_productivity_linux() {
    # LibreOffice
    detect_tool "LibreOffice" "libreoffice" "--version" "head -1"

    # Slack
    if command -v slack >/dev/null 2>&1; then
        output "  Slack: $(slack --version 2>/dev/null || echo "installed")"
    else
        output "  Slack: not installed"
    fi

    # Microsoft Teams
    if command -v teams >/dev/null 2>&1; then
        output "  Microsoft Teams: $(teams --version 2>/dev/null || echo "installed")"
    else
        output "  Microsoft Teams: not installed"
    fi

    # Webex
    if command -v webex >/dev/null 2>&1; then
        output "  Cisco Webex: $(webex --version 2>/dev/null || echo "installed")"
    else
        output "  Cisco Webex: not installed"
    fi

    # Discord
    if command -v discord >/dev/null 2>&1; then
        output "  Discord: $(discord --version 2>/dev/null || echo "installed")"
    else
        output "  Discord: not installed"
    fi

    # Skype
    if command -v skype >/dev/null 2>&1 || command -v skypeforlinux >/dev/null 2>&1; then
        output "  Skype: $(skypeforlinux --version 2>/dev/null || skype --version 2>/dev/null || echo "installed")"
    else
        output "  Skype: not installed"
    fi
}
