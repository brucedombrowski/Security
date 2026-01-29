#!/bin/bash
#
# Containers and Virtualization Collector
#
# Purpose: Collect container runtimes and virtualization software versions
# NIST Control: CM-8 (System Component Inventory), SC-7 (Boundary Protection)
#
# Functions:
#   collect_containers() - Collect container and VM software versions
#
# Dependencies: output.sh (for output function), detect.sh (for detect_tool, detect_macos_app)
#
# Note: This file is sourced, not executed directly

# Prevent direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly." >&2
    exit 1
fi

# Collect container and virtualization software versions
# Usage: collect_containers
collect_containers() {
    output "Containers and Virtualization:"
    output "------------------------------"

    # Cross-platform container tools
    _collect_container_runtimes

    # Platform-specific virtualization
    if [[ "$(uname)" == "Darwin" ]]; then
        _collect_virtualization_macos
    elif [[ "$(uname)" == "Linux" ]]; then
        _collect_virtualization_linux
    fi

    output ""
}

# Internal: Collect container runtimes (cross-platform)
_collect_container_runtimes() {
    # Docker
    detect_tool "Docker" "docker" "--version" "head -1"

    # Podman (with detailed info)
    if command -v podman >/dev/null 2>&1; then
        output "  Podman:"

        # Check if podman machine is running (macOS) or podman is accessible
        if podman info >/dev/null 2>&1; then
            # Capture full podman version output (Client and Server)
            while IFS= read -r line; do
                output "    $line"
            done <<< "$(podman version 2>/dev/null)"

            # List running containers with IPs
            local container_count
            container_count=$(podman ps -q 2>/dev/null | wc -l | tr -d ' ')
            if [ "$container_count" -gt 0 ]; then
                output "    Running Containers: $container_count"
                # Get container details (name, image, IP)
                while IFS= read -r container_id; do
                    if [ -n "$container_id" ]; then
                        local name image ip
                        name=$(podman inspect -f '{{.Name}}' "$container_id" 2>/dev/null | sed 's/^\///')
                        image=$(podman inspect -f '{{.Config.Image}}' "$container_id" 2>/dev/null)
                        ip=$(podman inspect -f '{{.NetworkSettings.IPAddress}}' "$container_id" 2>/dev/null)
                        output "      - $name ($image): $ip"
                    fi
                done <<< "$(podman ps -q 2>/dev/null)"
            else
                output "    Running Containers: 0"
            fi

            # List podman networks
            output "    Networks:"
            while IFS= read -r network; do
                if [ -n "$network" ] && [ "$network" != "NETWORK ID" ]; then
                    local net_name net_driver
                    net_name=$(echo "$network" | awk '{print $1}')
                    net_driver=$(echo "$network" | awk '{print $2}')
                    output "      - $net_name ($net_driver)"
                fi
            done <<< "$(podman network ls --format '{{.Name}} {{.Driver}}' 2>/dev/null)"
        else
            output "    Status: not running (podman machine not started)"
        fi

        # pasta (Linux rootless networking - replacement for slirp4netns)
        if command -v pasta >/dev/null 2>&1; then
            output "    pasta:"
            local pasta_ver
            pasta_ver=$(pasta --version 2>/dev/null)
            if [ -n "$pasta_ver" ]; then
                while IFS= read -r line; do
                    [ -n "$line" ] && output "      $line"
                done <<< "$pasta_ver"
            else
                # Fallback: get version from package manager
                if command -v rpm >/dev/null 2>&1; then
                    output "      $(rpm -q passt 2>/dev/null || echo 'version unknown')"
                elif command -v dpkg >/dev/null 2>&1; then
                    output "      $(dpkg -l passt 2>/dev/null | grep passt | awk '{print $3}' || echo 'version unknown')"
                else
                    output "      version unknown"
                fi
            fi
        fi

        # slirp4netns (Linux rootless networking)
        if command -v slirp4netns >/dev/null 2>&1; then
            output "    slirp4netns:"
            while IFS= read -r line; do
                [ -n "$line" ] && output "      $line"
            done <<< "$(slirp4netns --version 2>/dev/null)"
        fi
    else
        output "  Podman: not installed"
    fi

    # Kubernetes (kubectl)
    if command -v kubectl >/dev/null 2>&1; then
        output "  kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null | head -1)"
    else
        output "  kubectl: not installed"
    fi

    # Minikube
    if command -v minikube >/dev/null 2>&1; then
        output "  Minikube: $(minikube version --short 2>/dev/null || minikube version 2>/dev/null | head -1)"
    else
        output "  Minikube: not installed"
    fi

    # Helm
    if command -v helm >/dev/null 2>&1; then
        output "  Helm: $(helm version --short 2>/dev/null)"
    else
        output "  Helm: not installed"
    fi

    # Vagrant
    detect_tool "Vagrant" "vagrant" "--version" "cat"
}

# Internal: Collect virtualization software on macOS
_collect_virtualization_macos() {
    # VirtualBox
    detect_macos_app "VirtualBox" "/Applications/VirtualBox.app"

    # VMware Fusion
    detect_macos_app "VMware Fusion" "/Applications/VMware Fusion.app"

    # Parallels
    detect_macos_app "Parallels Desktop" "/Applications/Parallels Desktop.app"
}

# Internal: Collect virtualization software on Linux
_collect_virtualization_linux() {
    # VirtualBox
    if command -v VBoxManage >/dev/null 2>&1; then
        output "  VirtualBox: $(VBoxManage --version 2>/dev/null)"
    else
        output "  VirtualBox: not installed"
    fi

    # VMware Workstation
    if command -v vmware >/dev/null 2>&1; then
        output "  VMware Workstation: $(vmware --version 2>/dev/null | head -1)"
    else
        output "  VMware Workstation: not installed"
    fi

    # QEMU
    if command -v qemu-system-x86_64 >/dev/null 2>&1; then
        output "  QEMU: $(qemu-system-x86_64 --version 2>/dev/null | head -1)"
    elif command -v qemu-img >/dev/null 2>&1; then
        output "  QEMU: $(qemu-img --version 2>/dev/null | head -1)"
    else
        output "  QEMU: not installed"
    fi

    # libvirt/KVM
    if command -v virsh >/dev/null 2>&1; then
        output "  libvirt: $(virsh --version 2>/dev/null)"
    else
        output "  libvirt: not installed"
    fi

    # LXC/LXD
    if command -v lxc >/dev/null 2>&1; then
        output "  LXC/LXD: $(lxc --version 2>/dev/null)"
    else
        output "  LXC/LXD: not installed"
    fi
}
