#!/bin/bash
#
# Scanner-Side VPN Connection Helper
#
# Purpose: Help the scanner (Kali) connect to a target over Tailscale or WireGuard
#
# Usage:
#   ./scripts/vpn-connect.sh tailscale        # Check/start Tailscale
#   ./scripts/vpn-connect.sh wireguard        # Interactive WireGuard setup
#   ./scripts/vpn-connect.sh status           # Show VPN status
#   ./scripts/vpn-connect.sh --help           # Help
#
# Exit codes:
#   0 = Success
#   1 = Failure

set -eu

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_step()    { echo -e "${BLUE}[*]${NC} $1"; }
log_success() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[-]${NC} $1"; }

# ============================================================================
# Tailscale
# ============================================================================

vpn_tailscale() {
    echo ""
    echo -e "${BOLD}Tailscale VPN — Scanner Side${NC}"
    echo "============================"
    echo ""

    if ! command -v tailscale &>/dev/null; then
        log_error "Tailscale is not installed"
        echo ""
        echo "  Install: https://tailscale.com/download"
        echo "  macOS:   brew install tailscale"
        echo "  Linux:   curl -fsSL https://tailscale.com/install.sh | sh"
        echo ""
        exit 1
    fi

    log_success "Tailscale installed"

    # Check current status
    local status
    status=$(tailscale status 2>&1) || true

    if echo "$status" | grep -q "Tailscale is stopped"; then
        log_warn "Tailscale is not connected"
        echo ""
        echo -e "  Run: ${BOLD}sudo tailscale up${NC}"
        echo ""
        read -rp "Start Tailscale now? [Y/n] " answer </dev/tty
        if [ "${answer:-Y}" != "n" ] && [ "${answer:-Y}" != "N" ]; then
            if sudo tailscale up; then
                log_success "Tailscale connected"
            else
                log_error "tailscale up failed"
                exit 1
            fi
        fi
    else
        log_success "Tailscale is connected"
    fi

    # Show status
    echo ""
    echo -e "${BOLD}Tailscale Status:${NC}"
    tailscale status 2>/dev/null || true
    echo ""

    local my_ip
    my_ip=$(tailscale ip -4 2>/dev/null || echo "unknown")
    echo -e "${BOLD}Your Tailscale IP:${NC} $my_ip"
    echo ""

    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Check the target's TARGET READY screen for its Tailscale IP"
    echo "  2. Verify connectivity:  ping <target-tailscale-ip>"
    echo "  3. SSH to target:        ssh payload@<target-tailscale-ip>"
    echo "  4. Run scan:             ./QuickStart.sh -> Remote -> <target-tailscale-ip>"
    echo ""
}

# ============================================================================
# WireGuard
# ============================================================================

vpn_wireguard() {
    echo ""
    echo -e "${BOLD}WireGuard VPN — Scanner Side (Interactive Setup)${NC}"
    echo "================================================="
    echo ""

    if ! command -v wg &>/dev/null; then
        log_error "wireguard-tools is not installed"
        echo ""
        echo "  macOS:  brew install wireguard-tools"
        echo "  Kali:   sudo apt install wireguard-tools"
        echo ""
        exit 1
    fi

    log_success "wireguard-tools installed"
    echo ""

    # Collect target info from operator
    echo -e "${BOLD}Enter target information from the TARGET READY screen:${NC}"
    echo ""

    local target_pubkey target_endpoint
    read -rp "  Target public key: " target_pubkey </dev/tty
    if [ -z "$target_pubkey" ]; then
        log_error "Public key is required"
        exit 1
    fi

    read -rp "  Target endpoint (ip:port, e.g. 203.0.113.5:51820): " target_endpoint </dev/tty
    if [ -z "$target_endpoint" ]; then
        log_error "Endpoint is required for raw WireGuard"
        exit 1
    fi

    local iface="wg0"
    local scanner_ip="10.200.200.1/24"
    local target_tunnel_ip="10.200.200.2"

    echo ""
    echo -e "${BOLD}Scanner tunnel config:${NC}"
    echo "  Interface:  $iface"
    echo "  Scanner IP: $scanner_ip"
    echo "  Target IP:  $target_tunnel_ip"
    echo ""

    # Generate keypair
    local privkey pubkey
    privkey=$(wg genkey)
    pubkey=$(echo "$privkey" | wg pubkey)

    # Write config
    local conf_file="/etc/wireguard/${iface}.conf"
    echo -e "Writing config to ${BOLD}${conf_file}${NC}..."

    sudo tee "$conf_file" > /dev/null <<WGCONF
[Interface]
PrivateKey = $privkey
Address = $scanner_ip

[Peer]
PublicKey = $target_pubkey
Endpoint = $target_endpoint
AllowedIPs = ${target_tunnel_ip}/32
PersistentKeepalive = 25
WGCONF
    sudo chmod 600 "$conf_file"
    log_success "WireGuard config written"

    # Bring up interface
    echo ""
    log_step "Bringing up $iface..."
    if sudo wg-quick up "$iface" 2>&1; then
        log_success "WireGuard interface $iface is up"
    else
        log_error "wg-quick up failed"
        exit 1
    fi

    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}  SCANNER WIREGUARD CONNECTED${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}Scanner public key:${NC}"
    echo -e "    ${BOLD}$pubkey${NC}"
    echo ""
    echo -e "  ${BOLD}Target operator — run this on the target:${NC}"
    echo -e "    sudo wg set $iface peer $pubkey allowed-ips ${scanner_ip%%/*}/32"
    echo ""
    echo -e "  ${BOLD}Then verify connectivity:${NC}"
    echo -e "    ping $target_tunnel_ip"
    echo -e "    ssh payload@$target_tunnel_ip"
    echo ""
    echo -e "  ${BOLD}Teardown:${NC}"
    echo -e "    sudo wg-quick down $iface"
    echo ""
}

# ============================================================================
# Status
# ============================================================================

vpn_status() {
    echo ""
    echo -e "${BOLD}VPN Status${NC}"
    echo "=========="
    echo ""

    # Tailscale
    if command -v tailscale &>/dev/null; then
        local ts_ip
        ts_ip=$(tailscale ip -4 2>/dev/null || echo "")
        if [ -n "$ts_ip" ]; then
            log_success "Tailscale: connected ($ts_ip)"
        else
            log_warn "Tailscale: installed but not connected"
        fi
    else
        echo -e "  Tailscale: not installed"
    fi

    # WireGuard
    local wg_found=false
    for iface in $(ip link show type wireguard 2>/dev/null | grep -oP '^\d+: \K[^:]+' || true); do
        wg_found=true
        local wg_ip
        wg_ip=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[0-9.]+' || echo "no IP")
        log_success "WireGuard: $iface ($wg_ip)"
    done
    if [ "$wg_found" = false ]; then
        if command -v wg &>/dev/null; then
            echo -e "  WireGuard: installed, no active interfaces"
        else
            echo -e "  WireGuard: not installed"
        fi
    fi

    echo ""
}

# ============================================================================
# Main
# ============================================================================

usage() {
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  tailscale    Check/start Tailscale connection"
    echo "  wireguard    Interactive WireGuard setup with target"
    echo "  status       Show current VPN status"
    echo ""
    echo "Examples:"
    echo "  $0 tailscale          # Verify Tailscale, connect if needed"
    echo "  $0 wireguard          # Set up WireGuard tunnel to target"
    echo "  $0 status             # Show all VPN connections"
}

case "${1:-}" in
    tailscale|ts)
        vpn_tailscale
        ;;
    wireguard|wg)
        vpn_wireguard
        ;;
    status)
        vpn_status
        ;;
    --help|-h|"")
        usage
        ;;
    *)
        log_error "Unknown command: $1"
        echo ""
        usage
        exit 1
        ;;
esac
