#!/bin/bash
#
# Programming Languages Collector
#
# Purpose: Collect installed programming language runtime versions
# NIST Control: CM-8 (System Component Inventory)
#
# Functions:
#   collect_languages() - Collect programming language runtime versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect programming language runtime versions
# Usage: collect_languages
collect_languages() {
    output "Programming Languages:"
    output "----------------------"

    # Python
    if command -v python3 >/dev/null 2>&1; then
        output "  Python: $(python3 --version 2>/dev/null)"
    elif command -v python >/dev/null 2>&1; then
        output "  Python: $(python --version 2>/dev/null)"
    else
        output "  Python: not installed"
    fi

    # Node.js
    detect_tool "Node.js" "node" "--version" "cat"

    # Java (outputs to stderr)
    detect_tool_stderr "Java" "java" "-version"

    # .NET
    detect_tool ".NET" "dotnet" "--version" "cat"

    # Ruby
    detect_tool "Ruby" "ruby" "--version" "cat"

    # Go
    detect_tool "Go" "go" "version" "cat"

    # Rust
    detect_tool "Rust" "rustc" "--version" "cat"

    # Perl (special version extraction)
    if command -v perl >/dev/null 2>&1; then
        output "  Perl: $(perl --version 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    else
        output "  Perl: not installed"
    fi

    # PHP
    detect_tool "PHP" "php" "--version" "head -1"

    # Bash (special version extraction)
    if command -v bash >/dev/null 2>&1; then
        output "  Bash: $(bash --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    else
        output "  Bash: not installed"
    fi

    # Zsh
    detect_tool "Zsh" "zsh" "--version" "cat"

    # Lua
    detect_tool_stderr "Lua" "lua" "-v"

    # R
    detect_tool "R" "R" "--version" "head -1"

    # Swift
    detect_tool "Swift" "swift" "--version" "head -1"

    # Kotlin (outputs to stderr)
    detect_tool_stderr "Kotlin" "kotlin" "-version"

    # Scala (outputs to stderr)
    detect_tool_stderr "Scala" "scala" "-version"

    # Groovy
    detect_tool "Groovy" "groovy" "--version" "head -1"

    # TypeScript
    detect_tool "TypeScript" "tsc" "--version" "cat"

    # Elixir
    if command -v elixir >/dev/null 2>&1; then
        output "  Elixir: $(elixir --version 2>/dev/null | grep Elixir | head -1)"
    else
        output "  Elixir: not installed"
    fi

    # Haskell (GHC)
    detect_tool "Haskell (GHC)" "ghc" "--version" "cat"

    # Julia
    detect_tool "Julia" "julia" "--version" "cat"

    output ""
}
