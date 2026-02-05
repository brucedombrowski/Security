#!/bin/bash
#
# QuickStart OpenVAS/GVM Integration
#
# Purpose: Run OpenVAS vulnerability scans via CLI
# Used by: QuickStart.sh
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# ============================================================================
# OpenVAS Configuration
# ============================================================================

OPENVAS_COMPOSE_FILE="$HOME/greenbone-community-container/docker-compose.yml"
OPENVAS_AVAILABLE=false
OPENVAS_MODE=""  # "docker" or "native"

# Native GVM socket path (Kali/Debian)
OPENVAS_NATIVE_SOCKET="/run/gvmd/gvmd.sock"

# Credentials - override these in config file if needed
OPENVAS_USERNAME="${OPENVAS_USERNAME:-admin}"
OPENVAS_PASSWORD="${OPENVAS_PASSWORD:-}"

# Check if OpenVAS/GVM is available
check_openvas_available() {
    OPENVAS_AVAILABLE=false
    OPENVAS_MODE=""

    # Check for native GVM (Kali/Debian) - prefer this if available
    if [ -S "$OPENVAS_NATIVE_SOCKET" ] && command -v gvm-cli &>/dev/null; then
        # Check if gvmd service is running
        if systemctl is-active --quiet gvmd 2>/dev/null; then
            OPENVAS_AVAILABLE=true
            OPENVAS_MODE="native"
            return 0
        fi
    fi

    # Check for Docker-based GVM
    if [ -f "$OPENVAS_COMPOSE_FILE" ]; then
        if docker compose -f "$OPENVAS_COMPOSE_FILE" ps 2>/dev/null | grep -q "gvmd.*Up"; then
            OPENVAS_AVAILABLE=true
            OPENVAS_MODE="docker"
            return 0
        fi
    fi

    return 1
}

# Run GVM command - automatically uses native or Docker
gvm_cmd() {
    local cmd="$1"

    if [ "$OPENVAS_MODE" = "native" ]; then
        gvm_native_cmd "$cmd"
    else
        gvm_cmd "$cmd"
    fi
}

# Run GVM command via native installation (Kali/Debian)
gvm_native_cmd() {
    local cmd="$1"
    # Use sg _gvm to run with correct group permissions for socket access
    sg _gvm -c "gvm-cli --gmp-username '$OPENVAS_USERNAME' --gmp-password '$OPENVAS_PASSWORD' \
        socket --socketpath '$OPENVAS_NATIVE_SOCKET' \
        --xml '$cmd'" 2>&1
}

# Run GVM command via Docker
gvm_docker_cmd() {
    local cmd="$1"
    # Use 'run --rm' instead of 'exec' because gvm-tools is a transient container
    # Filter out docker compose status messages (Container ... Running/Creating/etc)
    docker compose -f "$OPENVAS_COMPOSE_FILE" run --rm -T gvm-tools \
        gvm-cli --gmp-username "$OPENVAS_USERNAME" --gmp-password "${OPENVAS_PASSWORD:-admin123}" \
        socket --socketpath /run/gvmd/gvmd.sock \
        --xml "$cmd" 2>&1 | grep -v "Container\|Creating\|Created\|Running\|Healthy\|Waiting"
}

# Extract ID from XML response (macOS compatible)
# Usage: extract_id "xml_string"
extract_id() {
    echo "$1" | grep -o 'id="[^"]*"' | head -1 | sed 's/id="//;s/"//'
}

# Get default port list ID
get_port_list_id() {
    local response
    response=$(gvm_cmd "<get_port_lists/>")
    # Use "All IANA assigned TCP and UDP" for comprehensive scanning
    echo "$response" | sed 's/<port_list/\n<port_list/g' | grep "All IANA assigned TCP and UDP" | grep -o 'id="[^"]*"' | head -1 | sed 's/id="//;s/"//'
}

# Get or create a target for scanning
# Usage: get_or_create_target "target_ip" "target_name"
# Returns: target_id
get_or_create_target() {
    local target_ip="$1"
    local target_name="${2:-QuickStart-$target_ip}"

    # Check if target already exists
    local response
    response=$(gvm_cmd "<get_targets filter=\"name=$target_name\"/>")
    local existing
    existing=$(extract_id "$response")

    if [ -n "$existing" ]; then
        echo "$existing"
        return 0
    fi

    # Get port list ID (required for target creation)
    local port_list_id
    port_list_id=$(get_port_list_id)
    if [ -z "$port_list_id" ]; then
        echo "Error: Could not find port list" >&2
        return 1
    fi

    # Create new target with port list
    response=$(gvm_cmd "<create_target><name>$target_name</name><hosts>$target_ip</hosts><port_list id=\"$port_list_id\"/></create_target>")
    extract_id "$response"
}

# Get the default scanner ID (OpenVAS Default)
get_scanner_id() {
    local response
    response=$(gvm_cmd "<get_scanners/>")
    # XML is on one line - extract scanner id that contains "OpenVAS Default"
    # The format is: <scanner id="xxx">...<name>OpenVAS Default</name>...
    echo "$response" | sed 's/<scanner/\n<scanner/g' | grep "OpenVAS Default" | grep -o 'id="[^"]*"' | head -1 | sed 's/id="//;s/"//'
}

# Get scan config ID
# Usage: get_config_id "config_name"
# Common configs: "Full and fast", "Base", "Discovery"
get_config_id() {
    local config_name="${1:-Full and fast}"
    local response
    response=$(gvm_cmd "<get_configs/>")
    # XML is on one line - extract config id that contains the config name
    echo "$response" | sed 's/<config/\n<config/g' | grep "$config_name" | grep -o 'id="[^"]*"' | head -1 | sed 's/id="//;s/"//'
}

# Create and start a scan task
# Usage: run_openvas_scan "target_ip" "output_dir" "timestamp" ["scan_type"]
# scan_type: "quick" (Discovery), "full" (Full and fast)
run_openvas_scan() {
    local target_ip="$1"
    local output_dir="$2"
    local timestamp="$3"
    local scan_type="${4:-quick}"

    local output_file="$output_dir/openvas-$timestamp.txt"
    local task_name="QuickStart-$timestamp"

    echo "Starting OpenVAS vulnerability scan..."
    echo "  Target: $target_ip"
    echo "  Type: $scan_type"
    echo ""

    # Get IDs
    echo "  Configuring scan..."
    local scanner_id
    scanner_id=$(get_scanner_id)
    if [ -z "$scanner_id" ]; then
        echo "  Error: Could not find OpenVAS scanner"
        return 1
    fi

    local config_name
    if [ "$scan_type" = "quick" ]; then
        config_name="Base"
    else
        config_name="Full and fast"
    fi

    local config_id
    config_id=$(get_config_id "$config_name")
    if [ -z "$config_id" ]; then
        echo "  Error: Could not find scan config '$config_name'"
        return 1
    fi

    local target_id
    target_id=$(get_or_create_target "$target_ip" "QuickStart-$target_ip")
    if [ -z "$target_id" ]; then
        echo "  Error: Could not create target"
        return 1
    fi

    # Create task
    echo "  Creating scan task..."
    local task_response
    task_response=$(gvm_cmd "<create_task><name>$task_name</name><config id=\"$config_id\"/><target id=\"$target_id\"/><scanner id=\"$scanner_id\"/></create_task>")

    local task_id
    task_id=$(extract_id "$task_response")

    if [ -z "$task_id" ]; then
        echo "  Error: Could not create task"
        echo "$task_response" >> "$output_file"
        return 1
    fi

    # Start task
    echo "  Starting scan (this may take 5-30 minutes)..."
    gvm_cmd "<start_task task_id=\"$task_id\"/>" > /dev/null

    # Write header to output file
    {
        echo "OpenVAS Vulnerability Scan"
        echo "=========================="
        echo "Target: $target_ip"
        echo "Started: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        echo "Scan Type: $scan_type ($config_name)"
        echo "Task ID: $task_id"
        echo ""
    } > "$output_file"

    # Poll for completion
    local status=""
    local progress=0
    local last_progress=-1
    local start_time=$(date +%s)
    local timeout=3600  # 60 minute timeout for full scans

    # Give task time to register before first status check
    echo "  Waiting for scan to initialize..."
    sleep 10

    # Disable terminal echo to prevent user input from corrupting progress display
    # Save current terminal settings and restore on exit
    local stty_saved=""
    if [ -t 0 ]; then
        stty_saved=$(stty -g 2>/dev/null || true)
        stty -echo 2>/dev/null || true
    fi

    # Ensure terminal echo is restored on exit (normal or interrupted)
    restore_terminal() {
        if [ -n "$stty_saved" ] && [ -t 0 ]; then
            stty "$stty_saved" 2>/dev/null || stty echo 2>/dev/null || true
        fi
    }
    trap restore_terminal EXIT INT TERM

    # Wait for scan to complete - continue while status is active OR empty (still initializing)
    # Exit only when we get a terminal status like "Done" or "Stopped"
    while true; do
        local task_info
        task_info=$(gvm_cmd "<get_tasks task_id=\"$task_id\"/>")
        status=$(echo "$task_info" | grep -o '<status>[^<]*' | head -1 | sed 's/<status>//')
        progress=$(echo "$task_info" | grep -o '<progress>[^<]*' | head -1 | sed 's/<progress>//' | cut -d'.' -f1)

        # Check for terminal states - exit loop when scan is done
        case "$status" in
            Done|Stopped|"Stop Requested"|Interrupted)
                break
                ;;
        esac

        # Show progress based on current state
        if [ -z "$status" ]; then
            echo -ne "\r  Initializing scan...                    "
        elif [ "$status" = "Queued" ] || [ "$status" = "New" ]; then
            echo -ne "\r  Waiting in queue...                     "
        elif [ "$status" = "Requested" ]; then
            echo -ne "\r  Scan starting...                        "
        elif [ -n "$progress" ] && [ "$progress" != "$last_progress" ]; then
            echo -ne "\r  Progress: ${progress}% (status: $status)   "
            last_progress="$progress"
        elif [ "$status" = "Running" ]; then
            echo -ne "\r  Running... (progress: ${progress:-0}%)   "
        fi

        # Check timeout
        local elapsed=$(($(date +%s) - start_time))
        if [ $elapsed -gt $timeout ]; then
            echo ""
            echo "  Warning: Scan timeout reached (60 min)"
            break
        fi

        sleep 15
    done

    echo ""

    # Restore terminal echo before continuing
    restore_terminal
    trap - EXIT INT TERM

    echo "  Scan completed with status: $status"

    # Get report
    local report_id
    report_id=$(gvm_cmd "<get_tasks task_id=\"$task_id\"/>" | grep -o '<report id="[^"]*"' | head -1 | sed 's/<report id="//;s/"//')

    if [ -n "$report_id" ]; then
        echo "  Fetching report..."

        # Get report in TXT format
        local report
        report=$(gvm_cmd "<get_reports report_id=\"$report_id\" format_id=\"a994b278-1f62-11e1-96ac-406186ea4fc5\"/>")

        # Append results to output file
        {
            echo "--- Scan Results ---"
            echo ""
            # Extract and decode the report content
            echo "$report" | grep -o '<report_format[^>]*>.*</report_format>' | head -1 || echo "$report"
            echo ""
            echo "--- End of Report ---"
            echo ""
            echo "Completed: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
        } >> "$output_file"

        # Parse summary
        local high_count medium_count low_count
        high_count=$(echo "$report" | grep -c "High" 2>/dev/null || echo "0")
        medium_count=$(echo "$report" | grep -c "Medium" 2>/dev/null || echo "0")
        low_count=$(echo "$report" | grep -c "Low" 2>/dev/null || echo "0")

        echo ""
        echo "  Results: High=$high_count, Medium=$medium_count, Low=$low_count"
        echo "  Report saved: $(basename "$output_file")"

        # Return success/fail based on high findings
        if [ "$high_count" -gt 0 ]; then
            return 1
        fi
    else
        echo "  Warning: Could not retrieve report"
        echo "  Check web UI at http://127.0.0.1:9392 for results"
        {
            echo "--- Report Not Available ---"
            echo "Check OpenVAS web UI for detailed results"
            echo "URL: http://127.0.0.1:9392"
            echo "Task ID: $task_id"
        } >> "$output_file"
    fi

    return 0
}

# Quick check if OpenVAS is running (native or Docker)
is_openvas_running() {
    # Check native first
    if systemctl is-active --quiet gvmd 2>/dev/null; then
        return 0
    fi
    # Check Docker
    if [ -f "$OPENVAS_COMPOSE_FILE" ]; then
        docker compose -f "$OPENVAS_COMPOSE_FILE" ps 2>/dev/null | grep -q "Up"
        return $?
    fi
    return 1
}

# Start OpenVAS services (native or Docker)
start_openvas() {
    # Try native first (Kali/Debian)
    if command -v gvm-start &>/dev/null; then
        echo "Starting OpenVAS services (native)..."
        sudo gvm-start
        echo "Waiting for services to initialize (10 seconds)..."
        sleep 10
        OPENVAS_MODE="native"
        return 0
    fi
    # Fall back to Docker
    if [ -f "$OPENVAS_COMPOSE_FILE" ]; then
        echo "Starting OpenVAS containers (Docker)..."
        docker compose -f "$OPENVAS_COMPOSE_FILE" up -d
        echo "Waiting for services to initialize (30 seconds)..."
        sleep 30
        OPENVAS_MODE="docker"
        return 0
    fi
    echo "OpenVAS not installed. Install with 'sudo apt install gvm' (Kali/Debian)"
    return 1
}
