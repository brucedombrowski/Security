#!/bin/bash
#
# Backup and Restore Software Collector
#
# Purpose: Collect installed backup software versions
# NIST Control: CM-8 (System Component Inventory), CP-9 (System Backup)
#
# Functions:
#   collect_backup() - Collect backup software versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool, detect_macos_app)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect backup software versions
# Usage: collect_backup
collect_backup() {
    output "Backup and Restore Software:"
    output "----------------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        _collect_backup_macos
    elif [[ "$(uname)" == "Linux" ]]; then
        _collect_backup_linux
    fi

    output ""
}

# Internal: Collect backup software on macOS
_collect_backup_macos() {
    # Time Machine status
    if command -v tmutil >/dev/null 2>&1; then
        local tm_status tm_dest
        tm_status=$(tmutil status 2>/dev/null | grep -q "Running = 1" && echo "running" || echo "idle")
        tm_dest=$(tmutil destinationinfo 2>/dev/null | grep "Name" | head -1 | awk -F': ' '{print $2}' || echo "not configured")
        output "  Time Machine: $tm_status (destination: $tm_dest)"
    else
        output "  Time Machine: not available"
    fi

    # Arq Backup
    if [ -d "/Applications/Arq.app" ] || [ -d "/Applications/Arq 7.app" ]; then
        local arq_ver
        arq_ver=$(defaults read "/Applications/Arq.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || \
                  defaults read "/Applications/Arq 7.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "unknown")
        output "  Arq Backup: $arq_ver"
    else
        output "  Arq Backup: not installed"
    fi

    # Carbon Copy Cloner
    detect_macos_app "Carbon Copy Cloner" "/Applications/Carbon Copy Cloner.app"

    # SuperDuper!
    detect_macos_app "SuperDuper!" "/Applications/SuperDuper!.app"

    # Backblaze
    detect_macos_app "Backblaze" "/Applications/Backblaze.app"
}

# Internal: Collect backup software on Linux
_collect_backup_linux() {
    # rsync
    detect_tool "rsync" "rsync" "--version" "head -1"

    # Borg Backup
    detect_tool "Borg Backup" "borg" "--version" "cat"

    # Restic
    detect_tool "Restic" "restic" "version" "cat"

    # Duplicity
    detect_tool "Duplicity" "duplicity" "--version" "cat"

    # Timeshift
    detect_tool "Timeshift" "timeshift" "--version" "head -1"
}
