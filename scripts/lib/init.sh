#!/bin/bash
#
# Security Toolkit Initialization Library
#
# Purpose: Centralized boilerplate for all toolkit scripts
# NIST Controls:
#   - CM-8 (System Component Inventory): Consistent toolkit identification
#   - AU-3 (Content of Audit Records): Standardized source attribution
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$SCRIPT_DIR/lib/init.sh"
#   init_security_toolkit "$@"
#
# This replaces ~20 lines of boilerplate in each script:
#   - Library sourcing with availability flags
#   - Toolkit info initialization
#   - Timestamp setup
#   - Common variable initialization
#
# After sourcing, these variables are available:
#   SCRIPT_DIR          - Directory containing the calling script
#   SECURITY_REPO_DIR   - Root of the security toolkit repository
#   LIB_DIR             - Directory containing library files
#   AUDIT_AVAILABLE     - 1 if audit-log.sh is loaded, 0 otherwise
#   TIMESTAMPS_AVAILABLE - 1 if timestamps.sh is loaded, 0 otherwise
#   PROGRESS_AVAILABLE  - 1 if progress.sh is loaded, 0 otherwise
#   TOOLKIT_AVAILABLE   - 1 if toolkit-info.sh is loaded, 0 otherwise
#   TIMESTAMP           - Current ISO 8601 UTC timestamp
#   TOOLKIT_VERSION     - Toolkit version (from git tag or config)
#   TOOLKIT_COMMIT      - Toolkit commit hash (short)

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    echo "Usage: source \"\$SCRIPT_DIR/lib/init.sh\"" >&2
    exit 1
fi

# ============================================================================
# Path Resolution
# ============================================================================

# Determine library directory from this file's location
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SCRIPT_DIR must be set by the calling script before sourcing
if [ -z "${SCRIPT_DIR:-}" ]; then
    # Fallback: assume caller is in scripts/ directory
    SCRIPT_DIR="$(cd "$LIB_DIR/.." && pwd)"
fi

# Repository root is parent of scripts directory
SECURITY_REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================================
# Library Availability Flags
# ============================================================================

AUDIT_AVAILABLE=0
TIMESTAMPS_AVAILABLE=0
PROGRESS_AVAILABLE=0
TOOLKIT_AVAILABLE=0

# ============================================================================
# Library Loading
# ============================================================================

# Source audit logging library
if [ -f "$LIB_DIR/audit-log.sh" ]; then
    source "$LIB_DIR/audit-log.sh"
    AUDIT_AVAILABLE=1
fi

# Source timestamp utilities
if [ -f "$LIB_DIR/timestamps.sh" ]; then
    source "$LIB_DIR/timestamps.sh"
    TIMESTAMPS_AVAILABLE=1
fi

# Source progress indicators
if [ -f "$LIB_DIR/progress.sh" ]; then
    source "$LIB_DIR/progress.sh"
    PROGRESS_AVAILABLE=1
fi

# Source toolkit info
if [ -f "$LIB_DIR/toolkit-info.sh" ]; then
    source "$LIB_DIR/toolkit-info.sh"
    TOOLKIT_AVAILABLE=1
fi

# ============================================================================
# Initialization Function
# ============================================================================

# Initialize the security toolkit environment
# Call this after sourcing to set up common variables
#
# Arguments:
#   None (uses SECURITY_REPO_DIR set above)
#
# Sets:
#   TIMESTAMP        - Current ISO 8601 UTC timestamp
#   TOOLKIT_VERSION  - Version from git or config
#   TOOLKIT_COMMIT   - Short commit hash
#
init_security_toolkit() {
    # Initialize toolkit info (version, commit, source)
    if [ "$TOOLKIT_AVAILABLE" -eq 1 ]; then
        init_toolkit_info "$SECURITY_REPO_DIR"
    else
        # Fallback if toolkit-info.sh not available
        TOOLKIT_VERSION=$(git -C "$SECURITY_REPO_DIR" describe --tags --always 2>/dev/null || echo "unknown")
        TOOLKIT_COMMIT=$(git -C "$SECURITY_REPO_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    # Set timestamp
    if [ "$TIMESTAMPS_AVAILABLE" -eq 1 ]; then
        TIMESTAMP=$(get_iso_timestamp)
    else
        TIMESTAMP=$(date -u "+%Y-%m-%dT%H:%M:%SZ")
    fi
}

# ============================================================================
# Target Directory Helper
# ============================================================================

# Parse target directory from arguments or use default
# Usage: TARGET_DIR=$(get_target_dir "$@")
#
# Arguments:
#   $@ - Script arguments (looks for first non-flag argument)
#
# Returns:
#   Target directory path (defaults to SECURITY_REPO_DIR)
#
get_target_dir() {
    local target=""

    for arg in "$@"; do
        # Skip flags
        case "$arg" in
            -*)
                continue
                ;;
            *)
                target="$arg"
                break
                ;;
        esac
    done

    if [ -n "$target" ]; then
        echo "$target"
    else
        echo "$SECURITY_REPO_DIR"
    fi
}

# ============================================================================
# Output Helpers
# ============================================================================

# Print script header with consistent formatting
# Usage: print_script_header "Script Name" "target_directory"
#
print_script_header() {
    local name="$1"
    local target="${2:-$SECURITY_REPO_DIR}"
    local repo_name
    repo_name=$(basename "$target")

    echo "$name"
    echo "$(printf '=%.0s' $(seq 1 ${#name}))"
    echo "Timestamp: $TIMESTAMP"
    echo "Target: $target"
    echo "Toolkit: $TOOLKIT_VERSION ($TOOLKIT_COMMIT)"
    echo ""
}

# ============================================================================
# Library Status (for debugging)
# ============================================================================

# Print which libraries are loaded
# Usage: print_library_status
#
print_library_status() {
    echo "Library Status:"
    echo "  audit-log.sh:    $([ "$AUDIT_AVAILABLE" -eq 1 ] && echo "loaded" || echo "not found")"
    echo "  timestamps.sh:   $([ "$TIMESTAMPS_AVAILABLE" -eq 1 ] && echo "loaded" || echo "not found")"
    echo "  progress.sh:     $([ "$PROGRESS_AVAILABLE" -eq 1 ] && echo "loaded" || echo "not found")"
    echo "  toolkit-info.sh: $([ "$TOOLKIT_AVAILABLE" -eq 1 ] && echo "loaded" || echo "not found")"
}
