#!/bin/bash
#
# Output Library for Host Inventory Collection
#
# Purpose: Handle output to file or stdout with CUI protections
# Used by: collect-host-inventory.sh and inventory collector modules
#
# Functions:
#   output()           - Output line to file or stdout
#   init_output()      - Initialize output file with proper permissions
#   show_cui_warning() - Display CUI warning to user
#   output_cui_header() - Output CUI header to inventory
#   output_cui_footer() - Output CUI footer to inventory
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Global: output file path (set by caller, empty for stdout)
OUTPUT_FILE="${OUTPUT_FILE:-}"

# Output line to file or stdout
# Usage: output "text"
output() {
    if [ -n "$OUTPUT_FILE" ]; then
        echo "$1" >> "$OUTPUT_FILE"
    else
        echo "$1"
    fi
}

# Initialize output file with proper permissions (mode 600)
# Usage: init_output "/path/to/file"
# Returns: 0 on success, warns on permission issues
init_output() {
    local file="$1"
    OUTPUT_FILE="$file"

    if [ -n "$OUTPUT_FILE" ]; then
        # CRITICAL-004: Create with restrictive permissions (mode 600)
        # Using umask 0077 already set above, but explicit chmod for clarity and safety
        > "$OUTPUT_FILE"
        chmod 600 "$OUTPUT_FILE" 2>/dev/null || true

        # Verify permissions were set correctly (NIST SP 800-171 AC-3)
        local file_mode
        if [[ "$(uname)" == "Darwin" ]]; then
            file_mode=$(stat -f "%OLp" "$OUTPUT_FILE" 2>/dev/null)
        else
            file_mode=$(stat -c "%a" "$OUTPUT_FILE" 2>/dev/null)
        fi
        if [ "${file_mode:-}" != "600" ]; then
            echo "WARNING: File permissions may not be fully restricted (mode: ${file_mode:-unknown}, expected 600)" >&2
        fi
    fi
}

# Display CUI warning to stderr
# Usage: show_cui_warning
show_cui_warning() {
    echo "" >&2
    echo "╔══════════════════════════════════════════════════════════════════════════╗" >&2
    echo "║ ⚠️  SECURITY WARNING: CONTROLLED UNCLASSIFIED INFORMATION (CUI)           ║" >&2
    echo "╚══════════════════════════════════════════════════════════════════════════╝" >&2
    echo "" >&2
    echo "Host inventory file contains CUI per NIST SP 800-171 and 32 CFR Part 2002:" >&2
    echo "" >&2
    echo "  Location: ${OUTPUT_FILE:-(stdout)}" >&2
    if [ -n "$OUTPUT_FILE" ]; then
        echo "  Permissions: 600 (owner read/write only)" >&2
    fi
    echo "" >&2
    echo "This file includes sensitive system information:" >&2
    echo "  • MAC addresses (network topology identification)" >&2
    echo "  • Hardware serial numbers (device identity)" >&2
    echo "  • Installed software versions (attack surface analysis)" >&2
    echo "  • System configuration details (security control details)" >&2
    echo "" >&2
    echo "REQUIRED HANDLING:" >&2
    echo "  1. Keep file permission-restricted (600) - verify with: ls -l" >&2
    echo "  2. Never upload to public cloud storage or repositories" >&2
    echo "  3. Never commit to version control (even private)" >&2
    echo "  4. Store on encrypted media or encrypted filesystems" >&2
    echo "  5. Delete securely when no longer needed" >&2
    echo "" >&2
    if [ -n "$OUTPUT_FILE" ]; then
        echo "For secure deletion instructions, see: scripts/secure-delete.sh" >&2
    fi
    echo "" >&2
}

# Output CUI header to inventory
# Usage: output_cui_header "$TIMESTAMP" "$TOOLKIT_NAME" "$TOOLKIT_VERSION" "$TOOLKIT_COMMIT" "$TOOLKIT_SOURCE"
output_cui_header() {
    local timestamp="$1"
    local toolkit_name="$2"
    local toolkit_version="$3"
    local toolkit_commit="$4"
    local toolkit_source="$5"

    output "////////////////////////////////////////////////////////////////////////////////"
    output "//                                                                            //"
    output "//                 CONTROLLED UNCLASSIFIED INFORMATION (CUI)                  //"
    output "//                                                                            //"
    output "//  CUI Category: CTI (Controlled Technical Information)                      //"
    output "//  Dissemination: FEDCON - Federal Contractors                               //"
    output "//  Safeguarding: Per NIST SP 800-171                                         //"
    output "//                                                                            //"
    output "////////////////////////////////////////////////////////////////////////////////"
    output ""
    output "Host System Inventory"
    output "====================="
    output "Generated: $timestamp"
    output "Hostname: $(hostname)"
    output "Toolkit: $toolkit_name $toolkit_version ($toolkit_commit)"
    output "Source: $toolkit_source"
    output ""
    output "HANDLING NOTICE:"
    output "  This document contains Controlled Unclassified Information (CUI)."
    output "  Contents include MAC addresses, serial numbers, and system inventory."
    output "  - Do not post to public repositories or websites"
    output "  - Limit distribution to authorized personnel"
    output "  - Store on encrypted media or systems"
    output "  - Destroy with: scripts/secure-delete.sh <file> (NIST SP 800-88)"
    output ""
}

# Output CUI footer to inventory
# Usage: output_cui_footer
output_cui_footer() {
    output ""
    output "====================="
    output "Inventory collection complete."
    output ""
    output "////////////////////////////////////////////////////////////////////////////////"
    output "//                                                                            //"
    output "//                 CONTROLLED UNCLASSIFIED INFORMATION (CUI)                  //"
    output "//                                                                            //"
    output "//  Reference: 32 CFR Part 2002, NIST SP 800-171                              //"
    output "//  Unauthorized disclosure subject to administrative/civil penalties         //"
    output "//                                                                            //"
    output "////////////////////////////////////////////////////////////////////////////////"
}
