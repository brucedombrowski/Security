#!/bin/bash
#
# Remote Desktop / Control Software Collector
#
# Purpose: Collect installed remote access software versions
# NIST Control: CM-8 (System Component Inventory), AC-17 (Remote Access)
#
# Functions:
#   collect_remote_desktop() - Collect remote access tool versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool, detect_macos_app)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect remote access software versions
# Usage: collect_remote_desktop
collect_remote_desktop() {
    output "Remote Desktop / Control Software:"
    output "-----------------------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        _collect_remote_desktop_macos
    elif [[ "$(uname)" == "Linux" ]]; then
        _collect_remote_desktop_linux
    fi

    output ""
}

# Internal: Collect remote desktop software on macOS
_collect_remote_desktop_macos() {
    # Screen Sharing (built-in)
    local screen_sharing
    screen_sharing=$(launchctl list 2>/dev/null | grep -q "com.apple.screensharing" && echo "enabled" || echo "disabled")
    output "  Screen Sharing (built-in): $screen_sharing"

    # Remote Desktop (ARD)
    if [ -d "/System/Library/CoreServices/RemoteManagement/ARDAgent.app" ]; then
        local ard_status
        ard_status=$(launchctl list 2>/dev/null | grep -q "com.apple.RemoteDesktop" && echo "enabled" || echo "disabled")
        output "  Apple Remote Desktop: $ard_status"
    fi

    # TeamViewer
    detect_macos_app "TeamViewer" "/Applications/TeamViewer.app"

    # AnyDesk
    detect_macos_app "AnyDesk" "/Applications/AnyDesk.app"

    # Zoom
    detect_macos_app "Zoom" "/Applications/zoom.us.app"

    # Microsoft Remote Desktop
    detect_macos_app "Microsoft Remote Desktop" "/Applications/Microsoft Remote Desktop.app"

    # VNC Viewer
    detect_macos_app "VNC Viewer" "/Applications/VNC Viewer.app"
}

# Internal: Collect remote desktop software on Linux
_collect_remote_desktop_linux() {
    # SSH Server status
    local sshd_status
    sshd_status=$(systemctl is-active sshd 2>/dev/null || systemctl is-active ssh 2>/dev/null || echo "unknown")
    output "  SSH Server: $sshd_status"

    # VNC Server
    if command -v vncserver >/dev/null 2>&1; then
        output "  VNC Server: $(vncserver -version 2>&1 | head -1 || echo "installed")"
    else
        output "  VNC Server: not installed"
    fi

    # xrdp
    if command -v xrdp >/dev/null 2>&1; then
        local xrdp_status
        xrdp_status=$(systemctl is-active xrdp 2>/dev/null || echo "unknown")
        output "  xrdp: $xrdp_status"
    else
        output "  xrdp: not installed"
    fi

    # TeamViewer
    if command -v teamviewer >/dev/null 2>&1; then
        output "  TeamViewer: $(teamviewer --version 2>/dev/null | head -1 || echo "installed")"
    else
        output "  TeamViewer: not installed"
    fi

    # AnyDesk
    if command -v anydesk >/dev/null 2>&1; then
        output "  AnyDesk: $(anydesk --version 2>/dev/null || echo "installed")"
    else
        output "  AnyDesk: not installed"
    fi

    # RustDesk
    if command -v rustdesk >/dev/null 2>&1; then
        output "  RustDesk: $(rustdesk --version 2>/dev/null || echo "installed")"
    else
        output "  RustDesk: not installed"
    fi
}
