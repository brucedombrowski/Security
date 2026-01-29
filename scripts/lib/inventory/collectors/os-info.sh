#!/bin/bash
#
# OS Information Collector
#
# Purpose: Collect operating system, kernel, and hardware information
# NIST Control: CM-8 (System Component Inventory)
#
# Functions:
#   collect_os_info() - Collect OS, kernel, and hardware details
#
# Dependencies: output.sh (for output function)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect operating system information
# Usage: collect_os_info
collect_os_info() {
    output "Operating System Information:"
    output "-----------------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        output "  Platform: macOS"
        output "  OS Version: $(sw_vers -productVersion)"
        output "  Build: $(sw_vers -buildVersion)"
        output "  Kernel: $(uname -r)"
        output "  Architecture: $(uname -m)"
        output "  Hardware Model: $(sysctl -n hw.model 2>/dev/null || echo 'Unknown')"
        output "  Serial Number: $(system_profiler SPHardwareDataType 2>/dev/null | grep "Serial Number" | awk -F': ' '{print $2}' || echo 'Unknown')"

    elif [[ "$(uname)" == "Linux" ]]; then
        output "  Platform: Linux"

        if [ -f /etc/os-release ]; then
            # Source os-release and use safe defaults for set -u compatibility
            . /etc/os-release
            output "  Distribution: ${NAME:-unknown}"
            output "  Version: ${VERSION:-unknown}"
            output "  Version ID: ${VERSION_ID:-unknown}"
        fi

        output "  Kernel: $(uname -r)"
        output "  Architecture: $(uname -m)"

        # Try to get hardware info
        if [ -f /sys/class/dmi/id/product_name ]; then
            output "  Hardware Model: $(cat /sys/class/dmi/id/product_name 2>/dev/null || echo 'Unknown')"
        fi
        if [ -f /sys/class/dmi/id/product_serial ]; then
            output "  Serial Number: $(cat /sys/class/dmi/id/product_serial 2>/dev/null || echo 'Unknown')"
        fi
    fi

    output ""
}
