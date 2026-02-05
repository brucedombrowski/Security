#!/bin/bash
#
# Shared Lynis Audit Module
#
# Purpose: Lynis security auditing for both local and remote targets
# Used by: local.sh, remote.sh
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Run Lynis security audit
#
# Arguments:
#   $1 - Command runner function name (empty string for local, "ssh_cmd" for remote)
#   $2 - Sudo command runner (empty for local sudo, "ssh_cmd_sudo" for remote)
#   $3 - Output file path
#   $4 - Target description (hostname or path)
#   $5 - Timestamp
#   $6 - Mode ("quick" or "full")
#
# Returns:
#   0 - Pass (audit completed successfully)
#   1 - Fail (audit had errors)
#   2 - Skip (Lynis not available)
#
# Side effects:
#   Sets LYNIS_RESULT to "PASS", "FAIL", or "SKIP"
#   Sets INSTALLED_LYNIS=true if Lynis was installed
#
run_lynis_audit() {
    local run_cmd="$1"
    local sudo_cmd="$2"
    local output_file="$3"
    local target_desc="$4"
    local timestamp="$5"
    local mode="${6:-quick}"

    # Check if lynis is available
    local lynis_check
    if [ -n "$run_cmd" ]; then
        lynis_check=$($run_cmd "command -v lynis" 2>/dev/null)
    else
        lynis_check=$(command -v lynis 2>/dev/null)
    fi

    if [ -n "$lynis_check" ]; then
        local lynis_opts=""
        [[ "$mode" == "quick" ]] && lynis_opts="--quick"

        if [[ "$mode" == "quick" ]]; then
            echo "  Lynis quick audit running (~2-5 minutes)..."
        else
            echo "  Lynis full audit running (~10-15 minutes)..."
        fi

        # Run the audit
        local raw_file="${output_file}.raw"
        if [ -n "$sudo_cmd" ]; then
            if $sudo_cmd "sudo lynis audit system $lynis_opts" 2>&1 | tee "$raw_file"; then
                # Strip ANSI codes if col is available
                if command -v col &>/dev/null; then
                    col -b < "$raw_file" > "$output_file"
                    rm -f "$raw_file"
                else
                    mv "$raw_file" "$output_file"
                fi
                LYNIS_RESULT="PASS"
                return 0
            else
                [ -f "$raw_file" ] && mv "$raw_file" "$output_file"
                LYNIS_RESULT="FAIL"
                return 1
            fi
        else
            if sudo lynis audit system $lynis_opts 2>&1 | tee "$raw_file"; then
                if command -v col &>/dev/null; then
                    col -b < "$raw_file" > "$output_file"
                    rm -f "$raw_file"
                else
                    mv "$raw_file" "$output_file"
                fi
                LYNIS_RESULT="PASS"
                return 0
            else
                [ -f "$raw_file" ] && mv "$raw_file" "$output_file"
                LYNIS_RESULT="FAIL"
                return 1
            fi
        fi
    else
        LYNIS_RESULT="SKIP"
        return 2
    fi
}

# Offer to install Lynis and run audit
#
# Arguments:
#   $1 - Command runner function name
#   $2 - Sudo command runner
#   $3 - Output file path
#   $4 - Target description
#   $5 - Timestamp
#   $6 - Mode ("quick" or "full")
#   $7 - Package manager hint ("apt", "brew", "dnf", etc.)
#
# Returns: Same as run_lynis_audit
#
offer_install_and_run_lynis() {
    local run_cmd="$1"
    local sudo_cmd="$2"
    local output_file="$3"
    local target_desc="$4"
    local timestamp="$5"
    local mode="${6:-quick}"
    local pkg_mgr="${7:-apt}"

    print_warning "Lynis not installed"
    echo -n "  Install Lynis now? [y/N]: "
    read -r install_ans </dev/tty

    if [[ "$install_ans" =~ ^[Yy] ]]; then
        echo "  Installing Lynis..."

        local install_cmd=""
        case "$pkg_mgr" in
            apt)    install_cmd="sudo apt install -y lynis" ;;
            brew)   install_cmd="brew install lynis" ;;
            dnf)    install_cmd="sudo dnf install -y lynis" ;;
            yum)    install_cmd="sudo yum install -y lynis" ;;
            pacman) install_cmd="sudo pacman -S --noconfirm lynis" ;;
        esac

        if [ -n "$sudo_cmd" ]; then
            if $sudo_cmd "$install_cmd" 2>&1; then
                print_success "Lynis installed"
                INSTALLED_LYNIS=true
            else
                print_error "Lynis installation failed"
                LYNIS_RESULT="SKIP"
                return 2
            fi
        else
            if eval "$install_cmd" 2>&1; then
                print_success "Lynis installed"
                INSTALLED_LYNIS=true
            else
                print_error "Lynis installation failed"
                LYNIS_RESULT="SKIP"
                return 2
            fi
        fi

        # Now run the audit
        run_lynis_audit "$run_cmd" "$sudo_cmd" "$output_file" "$target_desc" "$timestamp" "$mode"
        return $?
    else
        LYNIS_RESULT="SKIP"
        return 2
    fi
}

# Prompt for Lynis scan mode (quick vs full)
#
# Returns: Sets LYNIS_MODE to "quick" or "full"
#
prompt_lynis_mode() {
    while true; do
        echo -n "    Full scan (~10-15 min) or quick (~2 min)? [f/Q]: "
        read -r mode_ans </dev/tty
        case "$mode_ans" in
            [Ff]) LYNIS_MODE="full"; break ;;
            [Qq]|"") LYNIS_MODE="quick"; break ;;
            *) echo "    Invalid option. Enter 'f' for full or 'q' for quick." ;;
        esac
    done
}
