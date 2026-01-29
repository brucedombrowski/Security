#!/bin/bash
#
# Network Interfaces Collector
#
# Purpose: Collect network interface information including MAC addresses
# NIST Control: CM-8 (System Component Inventory), SC-8 (Transmission Confidentiality)
#
# Functions:
#   collect_network() - Collect network interfaces, MACs, IPs
#
# Dependencies: output.sh (for output function)
#
# Note: This file is sourced, not executed directly
# SENSITIVE: Collects MAC addresses (CUI)

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect network interface information
# Usage: collect_network
collect_network() {
    output "Network Interfaces:"
    output "-------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: Use ifconfig
        for iface in $(ifconfig -l); do
            # Skip loopback
            if [ "$iface" = "lo0" ]; then
                continue
            fi

            # Get MAC address
            local mac ipv4 ipv6 status media
            mac=$(ifconfig "$iface" 2>/dev/null | grep -i "ether" | awk '{print $2}')

            # Get IP addresses
            ipv4=$(ifconfig "$iface" 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
            ipv6=$(ifconfig "$iface" 2>/dev/null | grep "inet6 " | grep -v "fe80" | awk '{print $2}' | head -1)

            # Get status
            status=$(ifconfig "$iface" 2>/dev/null | grep -q "status: active" && echo "active" || echo "inactive")

            # Get media type
            media=$(ifconfig "$iface" 2>/dev/null | grep "media:" | sed 's/.*media: //' | head -1)

            if [ -n "$mac" ]; then
                output "  $iface:"
                output "    MAC Address: $mac"
                [ -n "$ipv4" ] && output "    IPv4: $ipv4"
                [ -n "$ipv6" ] && output "    IPv6: $ipv6"
                output "    Status: $status"
                [ -n "$media" ] && output "    Media: $media"
            fi
        done

    elif [[ "$(uname)" == "Linux" ]]; then
        # Linux: Use ip command
        if command -v ip >/dev/null 2>&1; then
            for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -v "^lo$"); do
                local mac ipv4 ipv6 state driver
                mac=$(ip link show "$iface" 2>/dev/null | grep "link/ether" | awk '{print $2}')
                ipv4=$(ip -4 addr show "$iface" 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
                ipv6=$(ip -6 addr show "$iface" 2>/dev/null | grep "inet6 " | grep -v "fe80" | awk '{print $2}' | head -1)
                state=$(ip link show "$iface" 2>/dev/null | grep -oP "state \K\w+")
                driver=$(ethtool -i "$iface" 2>/dev/null | grep "driver:" | awk '{print $2}')

                if [ -n "$mac" ]; then
                    output "  $iface:"
                    output "    MAC Address: $mac"
                    [ -n "$ipv4" ] && output "    IPv4: $ipv4"
                    [ -n "$ipv6" ] && output "    IPv6: $ipv6"
                    output "    State: $state"
                    [ -n "$driver" ] && output "    Driver: $driver"
                fi
            done
        else
            # Fallback to ifconfig
            output "  (Using legacy ifconfig - install iproute2 for detailed output)"
            ifconfig -a 2>/dev/null | grep -E "^[a-z]|ether|inet " || output "  Unable to enumerate interfaces"
        fi
    fi

    output ""
}
