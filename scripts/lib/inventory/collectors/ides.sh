#!/bin/bash
#
# Development Tools / IDEs Collector
#
# Purpose: Collect installed development environment versions
# NIST Control: CM-8 (System Component Inventory)
#
# Functions:
#   collect_ides() - Collect IDE and development tool versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_macos_app_paths, find_macos_ide_version)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect IDE and development tool versions
# Usage: collect_ides
collect_ides() {
    output "Development Tools / IDEs:"
    output "-------------------------"

    if [[ "$(uname)" == "Darwin" ]]; then
        _collect_ides_macos
    elif [[ "$(uname)" == "Linux" ]]; then
        _collect_ides_linux
    fi

    output ""
}

# Internal: Collect IDEs on macOS
_collect_ides_macos() {
    local ver

    # VS Code
    local vscode_paths=(
        "/Applications/Visual Studio Code.app"
        "$HOME/Applications/Visual Studio Code.app"
        "/Applications/Visual Studio Code - Insiders.app"
    )
    ver=$(find_macos_ide_version "${vscode_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  VS Code: $ver"
    else
        output "  VS Code: not installed"
    fi

    # Visual Studio for Mac
    local vs_paths=(
        "/Applications/Visual Studio.app"
        "$HOME/Applications/Visual Studio.app"
    )
    ver=$(find_macos_ide_version "${vs_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Visual Studio: $ver"
    else
        output "  Visual Studio: not installed"
    fi

    # Xcode
    local xcode_paths=(
        "/Applications/Xcode.app"
        "/Applications/Xcode-beta.app"
    )
    ver=$(find_macos_ide_version "${xcode_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Xcode: $ver"
    else
        output "  Xcode: not installed"
    fi

    # JetBrains IntelliJ IDEA
    local idea_paths=(
        "/Applications/IntelliJ IDEA.app"
        "/Applications/IntelliJ IDEA CE.app"
        "/Applications/IntelliJ IDEA Ultimate.app"
        "$HOME/Applications/IntelliJ IDEA.app"
        "$HOME/Applications/IntelliJ IDEA CE.app"
    )
    ver=$(find_macos_ide_version "${idea_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  IntelliJ IDEA: $ver"
    else
        output "  IntelliJ IDEA: not installed"
    fi

    # JetBrains PyCharm
    local pycharm_paths=(
        "/Applications/PyCharm.app"
        "/Applications/PyCharm CE.app"
        "$HOME/Applications/PyCharm.app"
        "$HOME/Applications/PyCharm CE.app"
    )
    ver=$(find_macos_ide_version "${pycharm_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  PyCharm: $ver"
    else
        output "  PyCharm: not installed"
    fi

    # JetBrains WebStorm
    local webstorm_paths=(
        "/Applications/WebStorm.app"
        "$HOME/Applications/WebStorm.app"
    )
    ver=$(find_macos_ide_version "${webstorm_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  WebStorm: $ver"
    else
        output "  WebStorm: not installed"
    fi

    # JetBrains GoLand
    local goland_paths=(
        "/Applications/GoLand.app"
        "$HOME/Applications/GoLand.app"
    )
    ver=$(find_macos_ide_version "${goland_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  GoLand: $ver"
    else
        output "  GoLand: not installed"
    fi

    # JetBrains Rider
    local rider_paths=(
        "/Applications/Rider.app"
        "$HOME/Applications/Rider.app"
    )
    ver=$(find_macos_ide_version "${rider_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Rider: $ver"
    else
        output "  Rider: not installed"
    fi

    # JetBrains CLion
    local clion_paths=(
        "/Applications/CLion.app"
        "$HOME/Applications/CLion.app"
    )
    ver=$(find_macos_ide_version "${clion_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  CLion: $ver"
    else
        output "  CLion: not installed"
    fi

    # JetBrains DataGrip
    local datagrip_paths=(
        "/Applications/DataGrip.app"
        "$HOME/Applications/DataGrip.app"
    )
    ver=$(find_macos_ide_version "${datagrip_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  DataGrip: $ver"
    else
        output "  DataGrip: not installed"
    fi

    # Eclipse
    local eclipse_paths=(
        "/Applications/Eclipse.app"
        "$HOME/Applications/Eclipse.app"
        "/Applications/Eclipse IDE.app"
    )
    ver=$(find_macos_ide_version "${eclipse_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Eclipse: $ver"
    else
        output "  Eclipse: not installed"
    fi

    # Sublime Text
    local sublime_paths=(
        "/Applications/Sublime Text.app"
        "$HOME/Applications/Sublime Text.app"
    )
    ver=$(find_macos_ide_version "${sublime_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Sublime Text: $ver"
    else
        output "  Sublime Text: not installed"
    fi

    # Atom
    local atom_paths=(
        "/Applications/Atom.app"
        "$HOME/Applications/Atom.app"
    )
    ver=$(find_macos_ide_version "${atom_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Atom: $ver"
    else
        output "  Atom: not installed"
    fi

    # Android Studio
    local android_paths=(
        "/Applications/Android Studio.app"
        "$HOME/Applications/Android Studio.app"
    )
    ver=$(find_macos_ide_version "${android_paths[@]}" || true)
    if [ -n "$ver" ]; then
        output "  Android Studio: $ver"
    else
        output "  Android Studio: not installed"
    fi
}

# Internal: Collect IDEs on Linux
_collect_ides_linux() {
    # VS Code - check command, snap, flatpak
    if command -v code >/dev/null 2>&1; then
        output "  VS Code: $(code --version 2>/dev/null | head -1)"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "^code "; then
        local vscode_snap
        vscode_snap=$(snap list 2>/dev/null | grep "^code " | awk '{print $2}')
        output "  VS Code: $vscode_snap (snap)"
    elif command -v flatpak >/dev/null 2>&1 && flatpak list --app 2>/dev/null | grep -q "com.visualstudio.code"; then
        output "  VS Code: (flatpak)"
    else
        output "  VS Code: not installed"
    fi

    # JetBrains IntelliJ IDEA
    if command -v idea >/dev/null 2>&1; then
        output "  IntelliJ IDEA: installed"
    elif [ -d "$HOME/.local/share/JetBrains/Toolbox/apps/IDEA" ] || [ -d "/opt/intellij-idea" ]; then
        output "  IntelliJ IDEA: installed"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "intellij"; then
        output "  IntelliJ IDEA: (snap)"
    else
        output "  IntelliJ IDEA: not installed"
    fi

    # PyCharm
    if command -v pycharm >/dev/null 2>&1; then
        output "  PyCharm: installed"
    elif [ -d "$HOME/.local/share/JetBrains/Toolbox/apps/PyCharm" ] || [ -d "/opt/pycharm" ]; then
        output "  PyCharm: installed"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "pycharm"; then
        output "  PyCharm: (snap)"
    else
        output "  PyCharm: not installed"
    fi

    # WebStorm
    if command -v webstorm >/dev/null 2>&1; then
        output "  WebStorm: installed"
    elif [ -d "$HOME/.local/share/JetBrains/Toolbox/apps/WebStorm" ]; then
        output "  WebStorm: installed"
    else
        output "  WebStorm: not installed"
    fi

    # GoLand
    if command -v goland >/dev/null 2>&1; then
        output "  GoLand: installed"
    elif [ -d "$HOME/.local/share/JetBrains/Toolbox/apps/GoLand" ]; then
        output "  GoLand: installed"
    else
        output "  GoLand: not installed"
    fi

    # Rider
    if command -v rider >/dev/null 2>&1; then
        output "  Rider: installed"
    elif [ -d "$HOME/.local/share/JetBrains/Toolbox/apps/Rider" ]; then
        output "  Rider: installed"
    else
        output "  Rider: not installed"
    fi

    # CLion
    if command -v clion >/dev/null 2>&1; then
        output "  CLion: installed"
    elif [ -d "$HOME/.local/share/JetBrains/Toolbox/apps/CLion" ]; then
        output "  CLion: installed"
    else
        output "  CLion: not installed"
    fi

    # Eclipse
    if command -v eclipse >/dev/null 2>&1; then
        output "  Eclipse: $(eclipse -version 2>/dev/null | head -1 || echo "installed")"
    elif [ -d "/opt/eclipse" ] || [ -d "$HOME/eclipse" ]; then
        output "  Eclipse: installed"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "eclipse"; then
        output "  Eclipse: (snap)"
    else
        output "  Eclipse: not installed"
    fi

    # Sublime Text
    if command -v subl >/dev/null 2>&1; then
        output "  Sublime Text: $(subl --version 2>/dev/null || echo "installed")"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "sublime-text"; then
        local sublime_snap
        sublime_snap=$(snap list 2>/dev/null | grep "sublime-text" | awk '{print $2}')
        output "  Sublime Text: $sublime_snap (snap)"
    else
        output "  Sublime Text: not installed"
    fi

    # Atom
    if command -v atom >/dev/null 2>&1; then
        output "  Atom: $(atom --version 2>/dev/null | head -1)"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "^atom "; then
        output "  Atom: (snap)"
    else
        output "  Atom: not installed"
    fi

    # Notepadqq (Notepad++ alternative for Linux)
    if command -v notepadqq >/dev/null 2>&1; then
        output "  Notepadqq: $(notepadqq --version 2>/dev/null || echo "installed")"
    else
        output "  Notepadqq: not installed"
    fi

    # Android Studio
    if command -v android-studio >/dev/null 2>&1 || [ -d "/opt/android-studio" ] || [ -d "$HOME/android-studio" ]; then
        output "  Android Studio: installed"
    elif command -v snap >/dev/null 2>&1 && snap list 2>/dev/null | grep -q "android-studio"; then
        output "  Android Studio: (snap)"
    else
        output "  Android Studio: not installed"
    fi
}
