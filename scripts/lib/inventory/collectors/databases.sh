#!/bin/bash
#
# Database Servers Collector
#
# Purpose: Collect installed database server versions
# NIST Control: CM-8 (System Component Inventory), SC-28 (Protection of Information at Rest)
#
# Functions:
#   collect_databases() - Collect database server versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect database server versions
# Usage: collect_databases
collect_databases() {
    output "Database Servers:"
    output "-----------------"

    # PostgreSQL
    detect_tool "PostgreSQL" "psql" "--version" "cat"

    # MySQL
    detect_tool "MySQL" "mysql" "--version" "cat"

    # SQLite
    detect_tool "SQLite" "sqlite3" "--version" "cat"

    # MongoDB
    detect_tool "MongoDB" "mongod" "--version" "head -1"

    # Redis
    detect_tool "Redis" "redis-server" "--version" "cat"

    output ""
}
