#!/bin/bash
#
# Security Tools Collector
#
# Purpose: Collect security-relevant software versions
# NIST Control: CM-8 (System Component Inventory), SI-3 (Malicious Code Protection)
#
# Functions:
#   collect_security_tools() - Collect ClamAV, OpenSSL, SSH, GPG, Git versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect security tools information
# Usage: collect_security_tools
collect_security_tools() {
    output "Security Tools:"
    output "---------------"

    # ClamAV
    detect_tool "ClamAV" "clamscan" "--version" "head -1"

    # OpenSSL
    detect_tool "OpenSSL" "openssl" "version" "cat"

    # SSH (outputs to stderr)
    detect_tool_stderr "SSH" "ssh" "-V"

    # GPG
    detect_tool "GPG" "gpg" "--version" "head -1"

    # Git
    detect_tool "Git" "git" "--version" "cat"

    output ""
}
