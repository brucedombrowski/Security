#!/bin/bash
#
# Web Servers Collector
#
# Purpose: Collect installed web server versions
# NIST Control: CM-8 (System Component Inventory), SC-7 (Boundary Protection)
#
# Functions:
#   collect_web_servers() - Collect web server versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect web server versions
# Usage: collect_web_servers
collect_web_servers() {
    output "Web Servers:"
    output "------------"

    # Apache (multiple command names)
    if command -v httpd >/dev/null 2>&1; then
        output "  Apache (httpd): $(httpd -v 2>/dev/null | head -1)"
    elif command -v apache2 >/dev/null 2>&1; then
        output "  Apache: $(apache2 -v 2>/dev/null | head -1)"
    elif command -v apachectl >/dev/null 2>&1; then
        output "  Apache: $(apachectl -v 2>/dev/null | head -1)"
    else
        output "  Apache: not installed"
    fi

    # Nginx (outputs to stderr)
    detect_tool_stderr "Nginx" "nginx" "-v"

    # Caddy
    detect_tool "Caddy" "caddy" "version" "cat"

    # Lighttpd
    detect_tool "Lighttpd" "lighttpd" "-v" "head -1"

    # Traefik
    detect_tool "Traefik" "traefik" "version" "head -1"

    output ""
}
