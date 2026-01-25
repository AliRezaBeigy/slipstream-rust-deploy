#!/bin/bash

# slipstream-rust Server Setup Script
# Supports Fedora, Rocky, CentOS, Debian, Ubuntu

set -e

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31m[ERROR]\033[0m This script must be run as root"
    exit 1
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
SCRIPT_URL="https://raw.githubusercontent.com/AliRezaBeigy/slipstream-rust-deploy/master/slipstream-rust-deploy.sh"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/slipstream-rust"
SYSTEMD_DIR="/etc/systemd/system"
SLIPSTREAM_USER="slipstream"
CONFIG_FILE="${CONFIG_DIR}/slipstream-rust-server.conf"
SCRIPT_INSTALL_PATH="/usr/local/bin/slipstream-rust-deploy"
BUILD_DIR="/opt/slipstream-rust"
REPO_URL="https://github.com/Mygod/slipstream-rust.git"
SLIPSTREAM_PORT="5300"
RELEASE_URL="https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download"

# Global variable to track if update is available
UPDATE_AVAILABLE=false

# Print functions
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_question() {
    echo -ne "${BLUE}[QUESTION]${NC} $1"
}

# Function to install/update the script itself
install_script() {
    print_status "Installing/updating slipstream-rust-deploy script..."

    # Download the latest version
    local temp_script="/tmp/slipstream-rust-deploy-new.sh"
    curl -Ls "$SCRIPT_URL" -o "$temp_script"

    # Make it executable
    chmod +x "$temp_script"

    # Check if we're updating an existing installation
    if [ -f "$SCRIPT_INSTALL_PATH" ]; then
        # Compare checksums to see if update is needed
        local current_checksum
        local new_checksum
        current_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | cut -d' ' -f1)
        new_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)

        if [ "$current_checksum" = "$new_checksum" ]; then
            print_status "Script is already up to date"
            rm "$temp_script"
            return 0
        else
            print_status "Updating existing script installation..."
        fi
    else
        print_status "Installing script for the first time..."
    fi

    # Copy to installation directory
    cp "$temp_script" "$SCRIPT_INSTALL_PATH"
    rm "$temp_script"

    print_status "Script installed to $SCRIPT_INSTALL_PATH"
    print_status "You can now run 'slipstream-rust-deploy' from anywhere"
}

# Function to handle manual update
update_script() {
    print_status "Checking for script updates..."

    local temp_script="/tmp/slipstream-rust-deploy-latest.sh"
    if ! curl -Ls "$SCRIPT_URL" -o "$temp_script"; then
        print_error "Failed to download latest version"
        return 1
    fi

    local current_checksum
    local latest_checksum
    current_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | cut -d' ' -f1)
    latest_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)

    if [ "$current_checksum" = "$latest_checksum" ]; then
        print_status "You are already running the latest version"
        rm "$temp_script"
        return 0
    fi

    print_status "New version available! Updating..."
    chmod +x "$temp_script"
    cp "$temp_script" "$SCRIPT_INSTALL_PATH"
    rm "$temp_script"
    print_status "Script updated successfully!"
    print_status "Restarting with new version..."

    # Restart the script with the new version immediately
    exec "$SCRIPT_INSTALL_PATH"
}

# Function to check for updates
check_for_updates() {
    # Only check for updates if we're running from the installed location
    if [ "$0" = "$SCRIPT_INSTALL_PATH" ]; then
        print_status "Checking for script updates..."

        local temp_script="/tmp/slipstream-rust-deploy-latest.sh"
        if curl -Ls "$SCRIPT_URL" -o "$temp_script" 2>/dev/null; then
            local current_checksum
            local latest_checksum
            current_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | cut -d' ' -f1)
            latest_checksum=$(sha256sum "$temp_script" | cut -d' ' -f1)

            if [ "$current_checksum" != "$latest_checksum" ]; then
                UPDATE_AVAILABLE=true
                print_warning "New version available! Use menu option 2 to update."
            else
                print_status "Script is up to date"
            fi
            rm "$temp_script"
        else
            print_warning "Could not check for updates (network issue)"
        fi
    fi
}

# Function to uninstall slipstream-rust
uninstall_slipstream() {
    print_warning "This will completely remove slipstream-rust from your system."
    print_question "Are you sure you want to uninstall? (y/N): "
    read -r confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_status "Uninstall cancelled."
        return 1
    fi

    print_status "Uninstalling slipstream-rust..."

    # Stop and disable slipstream-rust-server service
    if systemctl is-active --quiet slipstream-rust-server 2>/dev/null; then
        print_status "Stopping slipstream-rust-server service..."
        systemctl stop slipstream-rust-server
    fi
    if systemctl is-enabled --quiet slipstream-rust-server 2>/dev/null; then
        print_status "Disabling slipstream-rust-server service..."
        systemctl disable slipstream-rust-server
    fi

    # Remove systemd service file
    if [ -f "${SYSTEMD_DIR}/slipstream-rust-server.service" ]; then
        print_status "Removing systemd service file..."
        rm -f "${SYSTEMD_DIR}/slipstream-rust-server.service"
        systemctl daemon-reload
    fi

    # Stop and disable Dante if running
    if systemctl is-active --quiet danted 2>/dev/null; then
        print_status "Stopping Dante SOCKS service..."
        systemctl stop danted
    fi
    if systemctl is-enabled --quiet danted 2>/dev/null; then
        print_status "Disabling Dante SOCKS service..."
        systemctl disable danted
    fi

    # Stop and disable Shadowsocks if running
    if systemctl is-active --quiet shadowsocks-libev-server@config 2>/dev/null; then
        print_status "Stopping Shadowsocks service..."
        systemctl stop shadowsocks-libev-server@config
    fi
    if systemctl is-enabled --quiet shadowsocks-libev-server@config 2>/dev/null; then
        print_status "Disabling Shadowsocks service..."
        systemctl disable shadowsocks-libev-server@config
    fi
    # Remove Shadowsocks config if exists
    if [ -f /etc/shadowsocks-libev/config.json ]; then
        print_status "Removing Shadowsocks configuration..."
        rm -f /etc/shadowsocks-libev/config.json
    fi

    # Remove slipstream-server binary
    if [ -f "${INSTALL_DIR}/slipstream-server" ]; then
        print_status "Removing slipstream-server binary..."
        rm -f "${INSTALL_DIR}/slipstream-server"
    fi

    # Remove configuration directory
    if [ -d "$CONFIG_DIR" ]; then
        print_status "Removing configuration directory..."
        rm -rf "$CONFIG_DIR"
    fi

    # Remove build directory
    if [ -d "$BUILD_DIR" ]; then
        print_status "Removing build directory..."
        rm -rf "$BUILD_DIR"
    fi

    # Remove slipstream user
    if id "$SLIPSTREAM_USER" &>/dev/null; then
        print_status "Removing slipstream user..."
        userdel "$SLIPSTREAM_USER" 2>/dev/null || true
    fi

    # Remove iptables rules (best effort)
    print_status "Removing iptables rules..."
    iptables -D INPUT -p udp --dport "$SLIPSTREAM_PORT" -j ACCEPT 2>/dev/null || true
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -n "$interface" ]]; then
        iptables -t nat -D PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports "$SLIPSTREAM_PORT" 2>/dev/null || true
        if command -v ip6tables &> /dev/null; then
            ip6tables -D INPUT -p udp --dport "$SLIPSTREAM_PORT" -j ACCEPT 2>/dev/null || true
            ip6tables -t nat -D PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports "$SLIPSTREAM_PORT" 2>/dev/null || true
        fi
    fi

    # Ask about removing the deploy script itself
    print_question "Do you also want to remove the slipstream-rust-deploy script? (y/N): "
    read -r remove_script

    if [[ "$remove_script" =~ ^[Yy]$ ]]; then
        print_status "Removing slipstream-rust-deploy script..."
        rm -f "$SCRIPT_INSTALL_PATH"
        print_status "Uninstall complete! The deploy script has been removed."
    else
        print_status "Uninstall complete! The deploy script remains at $SCRIPT_INSTALL_PATH"
    fi

    return 0
}

# Function to show main menu
show_menu() {
    echo ""
    print_status "slipstream-rust Server Management"
    print_status "=================================="

    # Show update notification if available
    if [ "$UPDATE_AVAILABLE" = true ]; then
        echo -e "${YELLOW}[UPDATE AVAILABLE]${NC} A new version of this script is available!"
        echo -e "${YELLOW}                  ${NC} Use option 2 to update to the latest version."
        echo ""
    fi

    echo "1) Install/Reconfigure slipstream-rust server"
    echo "2) Update slipstream-rust-deploy script"
    echo "3) Check service status"
    echo "4) View service logs"
    echo "5) Show configuration info"
    echo "6) Uninstall slipstream-rust"
    echo "0) Exit"
    echo ""
    print_question "Please select an option (0-6): "
}

# Function to handle menu selection
handle_menu() {
    while true; do
        show_menu
        read -r choice

        case $choice in
            1)
                print_status "Starting slipstream-rust server installation/reconfiguration..."
                return 0  # Continue with main installation
                ;;
            2)
                update_script
                ;;
            3)
                if systemctl is-active --quiet slipstream-rust-server; then
                    print_status "slipstream-rust-server service is running"
                    systemctl status slipstream-rust-server --no-pager -l
                else
                    print_warning "slipstream-rust-server service is not running"
                    systemctl status slipstream-rust-server --no-pager -l
                fi
                ;;
            4)
                print_status "Showing slipstream-rust-server logs (Press Ctrl+C to exit)..."
                journalctl -u slipstream-rust-server -f
                ;;
            5)
                show_configuration_info
                ;;
            6)
                if uninstall_slipstream; then
                    exit 0
                fi
                ;;
            0)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 0-6."
                ;;
        esac

        if [ "$choice" != "4" ]; then
            echo ""
            print_question "Press Enter to continue..."
            read -r
        fi
    done
}

detect_active_mode() {
    if systemctl is-active --quiet shadowsocks-libev-server@config 2>/dev/null || \
       systemctl is-active --quiet shadowsocks-libev 2>/dev/null; then
        echo "shadowsocks"
        return 0
    fi
    
    if systemctl is-active --quiet danted 2>/dev/null; then
        echo "socks"
        return 0
    fi
    
    echo ""
    return 0
}

# Function to load existing configuration
load_existing_config() {
    if [ -f "$CONFIG_FILE" ]; then
        print_status "Loading existing configuration..."
        # Source the config file to load variables
        # shellcheck source=/dev/null
        . "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# Function to save configuration
save_config() {
    print_status "Saving configuration..."

    cat > "$CONFIG_FILE" << EOF
# slipstream-rust Server Configuration
# Generated on $(date)

DOMAIN="$DOMAIN"
TUNNEL_MODE="$TUNNEL_MODE"
CERT_FILE="$CERT_FILE"
KEY_FILE="$KEY_FILE"
EOF

    if [ "$TUNNEL_MODE" = "socks" ]; then
        cat >> "$CONFIG_FILE" << EOF
SOCKS_AUTH_ENABLED="${SOCKS_AUTH_ENABLED:-no}"
SOCKS_USERNAME="${SOCKS_USERNAME:-}"
SOCKS_PASSWORD="${SOCKS_PASSWORD:-}"
EOF
    fi

    if [ "$TUNNEL_MODE" = "shadowsocks" ]; then
        cat >> "$CONFIG_FILE" << EOF
SHADOWSOCKS_PORT="${SHADOWSOCKS_PORT:-8388}"
SHADOWSOCKS_PASSWORD="${SHADOWSOCKS_PASSWORD:-}"
SHADOWSOCKS_METHOD="${SHADOWSOCKS_METHOD:-aes-256-gcm}"
EOF
    fi

    chmod 640 "$CONFIG_FILE"
    chown root:"$SLIPSTREAM_USER" "$CONFIG_FILE"
    print_status "Configuration saved to $CONFIG_FILE"
}

# Function to show configuration information
show_configuration_info() {
    print_status "Current Configuration Information"
    print_status "================================"

    # Check if configuration file exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_warning "No configuration found. Please install/configure slipstream-rust server first."
        return 1
    fi

    # Load existing configuration
    if ! load_existing_config; then
        print_error "Failed to load configuration from $CONFIG_FILE"
        return 1
    fi

    # Check if service is running
    local service_status
    if systemctl is-active --quiet slipstream-rust-server; then
        service_status="${GREEN}Running${NC}"
    else
        service_status="${RED}Stopped${NC}"
    fi

    echo ""
    echo -e "${BLUE}Configuration Details:${NC}"
    echo -e "  Domain: ${YELLOW}$DOMAIN${NC}"
    echo -e "  Tunnel mode: ${YELLOW}$TUNNEL_MODE${NC}"
    echo -e "  Service user: ${YELLOW}$SLIPSTREAM_USER${NC}"
    echo -e "  Listen port: ${YELLOW}$SLIPSTREAM_PORT${NC} (DNS traffic redirected from port 53)"
    echo -e "  Service status: $service_status"
    echo ""

    echo -e "${BLUE}Management Commands:${NC}"
    echo -e "  Run menu:           ${YELLOW}slipstream-rust-deploy${NC}"
    echo -e "  Start service:      ${YELLOW}systemctl start slipstream-rust-server${NC}"
    echo -e "  Stop service:       ${YELLOW}systemctl stop slipstream-rust-server${NC}"
    echo -e "  Service status:     ${YELLOW}systemctl status slipstream-rust-server${NC}"
    echo -e "  View logs:          ${YELLOW}journalctl -u slipstream-rust-server -f${NC}"

    # Show SOCKS info if applicable
    if [ "$TUNNEL_MODE" = "socks" ]; then
        echo ""
        echo -e "${BLUE}SOCKS Proxy Information:${NC}"
        echo -e "SOCKS proxy is running on ${YELLOW}127.0.0.1:1080${NC}"
        if [[ "${SOCKS_AUTH_ENABLED:-no}" == "yes" && -n "${SOCKS_USERNAME:-}" ]]; then
            echo -e "Authentication: ${GREEN}Enabled${NC} (username: ${YELLOW}$SOCKS_USERNAME${NC})"
        else
            echo -e "Authentication: ${YELLOW}Disabled${NC}"
        fi
        echo -e "${BLUE}Dante service commands:${NC}"
        echo -e "  Status:  ${YELLOW}systemctl status danted${NC}"
        echo -e "  Stop:    ${YELLOW}systemctl stop danted${NC}"
        echo -e "  Start:   ${YELLOW}systemctl start danted${NC}"
        echo -e "  Logs:    ${YELLOW}journalctl -u danted -f${NC}"
    fi

    # Show Shadowsocks info if applicable
    if [ "$TUNNEL_MODE" = "shadowsocks" ]; then
        echo ""
        echo -e "${BLUE}Shadowsocks Information:${NC}"
        echo -e "Shadowsocks server is running on ${YELLOW}127.0.0.1:${SHADOWSOCKS_PORT:-8388}${NC}"
        echo -e "Encryption method: ${YELLOW}${SHADOWSOCKS_METHOD:-aes-256-gcm}${NC}"
        echo -e "${BLUE}Shadowsocks service commands:${NC}"
        echo -e "  Status:  ${YELLOW}systemctl status shadowsocks-libev-server@config${NC}"
        echo -e "  Stop:    ${YELLOW}systemctl stop shadowsocks-libev-server@config${NC}"
        echo -e "  Start:   ${YELLOW}systemctl start shadowsocks-libev-server@config${NC}"
        echo -e "  Logs:    ${YELLOW}journalctl -u shadowsocks-libev-server@config -f${NC}"
    fi

    echo ""
}

# Function to detect OS and package manager
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
    else
        print_error "Cannot detect OS"
        exit 1
    fi

    # Determine package manager
    if command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
    elif command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    else
        print_error "Unsupported package manager"
        exit 1
    fi

    print_status "Detected OS: $OS"
    print_status "Package manager: $PKG_MANAGER"
}

# Function to check and install required tools
check_required_tools() {
    print_status "Checking required tools..."

    local required_tools=("curl" "git" "rustc" "cargo" "cmake" "pkg-config")
    local missing_tools=()

    # Check which tools are missing
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    # Check for iptables separately since it might need special handling
    if ! command -v "iptables" &> /dev/null; then
        missing_tools+=("iptables")
    fi

    # Check for OpenSSL development headers
    if ! pkg-config --exists openssl 2>/dev/null; then
        missing_tools+=("openssl-dev")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_status "Installing missing tools: ${missing_tools[*]}"
        install_dependencies "${missing_tools[@]}"
    else
        print_status "All required tools are available"
    fi

    # Verify iptables installation after potential installation
    verify_iptables_installation
}

# Function to verify iptables installation and capabilities
verify_iptables_installation() {
    print_status "Verifying iptables installation..."

    if ! command -v iptables &> /dev/null; then
        print_error "iptables is not available after installation attempt"
        exit 1
    fi

    # Check if ip6tables is available (should be part of iptables package)
    if command -v ip6tables &> /dev/null; then
        print_status "Both iptables and ip6tables are available"
    else
        print_warning "ip6tables not found, IPv6 rules will be skipped"
    fi

    # Check if IPv6 is supported on the system
    if [ -f /proc/net/if_inet6 ]; then
        print_status "IPv6 support detected"
    else
        print_warning "IPv6 not supported on this system"
    fi
}

# Function to install dependencies
install_dependencies() {
    local tools=("$@")
    print_status "Installing dependencies: ${tools[*]}"

    # Safety check for PKG_MANAGER
    if [[ -z "$PKG_MANAGER" ]]; then
        print_error "Package manager not detected. Make sure detect_os() is called first."
        exit 1
    fi

    case $PKG_MANAGER in
        dnf|yum)
            # For RHEL-based systems
            local packages_to_install=()

            # Always install gcc-c++ for building picoquic (CMake requires C++ compiler)
            if ! command -v g++ &> /dev/null; then
                packages_to_install+=("gcc-c++")
            fi

            for tool in "${tools[@]}"; do
                case $tool in
                    "rustc"|"cargo")
                        # Rust toolchain - install via rustup if not available
                        if ! command -v rustc &> /dev/null; then
                            print_status "Installing Rust toolchain via rustup..."
                            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                            source "$HOME/.cargo/env" || source /root/.cargo/env
                        fi
                        ;;
                    "iptables")
                        packages_to_install+=("iptables" "iptables-services")
                        ;;
                    "openssl-dev")
                        packages_to_install+=("openssl-devel")
                        ;;
                    "cmake")
                        packages_to_install+=("cmake")
                        ;;
                    "pkg-config")
                        packages_to_install+=("pkgconfig")
                        ;;
                    *)
                        packages_to_install+=("$tool")
                        ;;
                esac
            done

            if [ ${#packages_to_install[@]} -gt 0 ]; then
                if ! $PKG_MANAGER install -y "${packages_to_install[@]}"; then
                    print_error "Failed to install packages: ${packages_to_install[*]}"
                    exit 1
                fi
            fi
            ;;
        apt)
            # For Debian-based systems
            if ! apt update; then
                print_error "Failed to update package lists"
                exit 1
            fi

            local packages_to_install=()

            # Always install g++ for building picoquic (CMake requires C++ compiler)
            if ! command -v g++ &> /dev/null; then
                packages_to_install+=("g++")
            fi

            for tool in "${tools[@]}"; do
                case $tool in
                    "rustc"|"cargo")
                        # Rust toolchain - install via rustup if not available
                        if ! command -v rustc &> /dev/null; then
                            print_status "Installing Rust toolchain via rustup..."
                            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
                            source "$HOME/.cargo/env" || source /root/.cargo/env
                        fi
                        ;;
                    "iptables")
                        packages_to_install+=("iptables" "iptables-persistent")
                        ;;
                    "openssl-dev")
                        packages_to_install+=("libssl-dev")
                        ;;
                    "cmake")
                        packages_to_install+=("cmake")
                        ;;
                    "pkg-config")
                        packages_to_install+=("pkg-config")
                        ;;
                    *)
                        packages_to_install+=("$tool")
                        ;;
                esac
            done

            if [ ${#packages_to_install[@]} -gt 0 ]; then
                if ! apt install -y "${packages_to_install[@]}"; then
                    print_error "Failed to install packages: ${packages_to_install[*]}"
                    exit 1
                fi
            fi
            ;;
        *)
            print_error "Unsupported package manager: $PKG_MANAGER"
            exit 1
            ;;
    esac

    print_status "Dependencies installed successfully"
}

# Function to get user input
get_user_input() {
    local existing_domain=""
    local existing_mode=""
    local existing_ss_port=""
    local existing_ss_method=""
    local existing_ss_password=""
    local existing_auth=""
    local existing_username=""

    if load_existing_config; then
        existing_domain="$DOMAIN"
        existing_mode="$TUNNEL_MODE"
        # Save Shadowsocks config if it exists
        existing_ss_port="${SHADOWSOCKS_PORT:-}"
        existing_ss_method="${SHADOWSOCKS_METHOD:-}"
        existing_ss_password="${SHADOWSOCKS_PASSWORD:-}"
        # Save SOCKS config if it exists
        existing_auth="${SOCKS_AUTH_ENABLED:-}"
        existing_username="${SOCKS_USERNAME:-}"
        print_status "Found existing configuration for domain: $existing_domain"
        # Clear TUNNEL_MODE so user's selection isn't overwritten
        unset TUNNEL_MODE
    fi
    
    local active_mode
    active_mode=$(detect_active_mode)
    if [[ -n "$active_mode" ]]; then
        existing_mode="$active_mode"
        print_status "Detected active tunnel mode: $active_mode"
    fi

    # Get domain
    while true; do
        if [[ -n "$existing_domain" ]]; then
            print_question "Enter the domain (current: $existing_domain): "
        else
            print_question "Enter the domain (e.g., example.com): "
        fi
        read -r DOMAIN

        # Use existing domain if user just presses enter
        if [[ -z "$DOMAIN" && -n "$existing_domain" ]]; then
            DOMAIN="$existing_domain"
        fi

        if [[ -n "$DOMAIN" ]]; then
            break
        else
            print_error "Please enter a valid domain"
        fi
    done

    # Get tunnel mode
    while true; do
        echo "Select tunnel mode:"
        echo "1) SOCKS proxy (Dante)"
        echo "2) SSH mode"
        echo "3) Shadowsocks"
        if [[ -n "$existing_mode" ]]; then
            local mode_number
            case "$existing_mode" in
                socks) mode_number="1" ;;
                ssh) mode_number="2" ;;
                shadowsocks) mode_number="3" ;;
                *) mode_number="?" ;;
            esac
            print_question "Enter choice (current: $mode_number - $existing_mode): "
        else
            print_question "Enter choice (1, 2, or 3): "
        fi
        read -r TUNNEL_MODE

        # Use existing mode if user just presses enter
        if [[ -z "$TUNNEL_MODE" && -n "$existing_mode" ]]; then
            TUNNEL_MODE="$existing_mode"
            break
        fi

        case $TUNNEL_MODE in
            1)
                TUNNEL_MODE="socks"
                break
                ;;
            2)
                TUNNEL_MODE="ssh"
                break
                ;;
            3)
                TUNNEL_MODE="shadowsocks"
                break
                ;;
            *)
                print_error "Invalid choice. Please enter 1, 2, or 3"
                ;;
        esac
    done

    SOCKS_AUTH_ENABLED="no"
    SOCKS_USERNAME=""
    SOCKS_PASSWORD=""
    
    if [ "$TUNNEL_MODE" = "socks" ]; then
        # Use saved SOCKS config from initial load (no need to reload)
        
        while true; do
            if [[ -n "${existing_auth:-}" ]]; then
                local auth_status="disabled"
                if [[ "$existing_auth" == "yes" ]]; then
                    auth_status="enabled"
                fi
                print_question "Enable username/password authentication for SOCKS proxy? (current: $auth_status) [y/N]: "
            else
                print_question "Enable username/password authentication for SOCKS proxy? [y/N]: "
            fi
            read -r enable_auth
            
            if [[ -z "$enable_auth" && -n "${existing_auth:-}" ]]; then
                SOCKS_AUTH_ENABLED="$existing_auth"
                if [[ "$existing_auth" == "yes" ]]; then
                    SOCKS_USERNAME="$existing_username"
                fi
                break
            fi
            
            case $enable_auth in
                [Yy]|[Yy][Ee][Ss])
                    SOCKS_AUTH_ENABLED="yes"
                    
                    while true; do
                        if [[ -n "${existing_username:-}" && "$SOCKS_AUTH_ENABLED" == "yes" ]]; then
                            print_question "Enter SOCKS username (current: $existing_username): "
                        else
                            print_question "Enter SOCKS username: "
                        fi
                        read -r SOCKS_USERNAME
                        
                        if [[ -z "$SOCKS_USERNAME" && -n "${existing_username:-}" ]]; then
                            SOCKS_USERNAME="$existing_username"
                        fi
                        
                        if [[ -n "$SOCKS_USERNAME" ]]; then
                            break
                        else
                            print_error "Please enter a valid username"
                        fi
                    done
                    
                    while true; do
                        print_question "Enter SOCKS password: "
                        read -rs SOCKS_PASSWORD
                        echo ""  # New line after hidden password input
                        
                        if [[ -z "$SOCKS_PASSWORD" ]]; then
                            print_error "Please enter a valid password"
                        else
                            print_question "Confirm SOCKS password: "
                            read -rs SOCKS_PASSWORD_CONFIRM
                            echo ""  # New line after hidden password input
                            
                            if [[ "$SOCKS_PASSWORD" != "$SOCKS_PASSWORD_CONFIRM" ]]; then
                                print_error "Passwords do not match. Please try again."
                                SOCKS_PASSWORD=""
                            else
                                break
                            fi
                        fi
                    done
                    break
                    ;;
                [Nn]|[Nn][Oo]|"")
                    SOCKS_AUTH_ENABLED="no"
                    break
                    ;;
                *)
                    print_error "Invalid choice. Please enter y or n"
                    ;;
            esac
        done
    fi

    # Shadowsocks configuration
    SHADOWSOCKS_PORT="8388"
    SHADOWSOCKS_PASSWORD=""
    SHADOWSOCKS_METHOD="aes-256-gcm"

    if [ "$TUNNEL_MODE" = "shadowsocks" ]; then
        # Use saved Shadowsocks config from initial load (no need to reload)
        # Variables are already saved as existing_ss_port, existing_ss_method, existing_ss_password

        # Get Shadowsocks port
        while true; do
            if [[ -n "${existing_ss_port:-}" ]]; then
                print_question "Enter Shadowsocks local port (current: $existing_ss_port): "
            else
                print_question "Enter Shadowsocks local port (default: 8388): "
            fi
            read -r input_port

            if [[ -z "$input_port" ]]; then
                if [[ -n "${existing_ss_port:-}" ]]; then
                    SHADOWSOCKS_PORT="$existing_ss_port"
                else
                    SHADOWSOCKS_PORT="8388"
                fi
                break
            elif [[ "$input_port" =~ ^[0-9]+$ ]] && [ "$input_port" -ge 1 ] && [ "$input_port" -le 65535 ]; then
                SHADOWSOCKS_PORT="$input_port"
                break
            else
                print_error "Please enter a valid port number (1-65535)"
            fi
        done

        # Get Shadowsocks password
        while true; do
            print_question "Enter Shadowsocks password: "
            read -rs SHADOWSOCKS_PASSWORD
            echo ""

            if [[ -z "$SHADOWSOCKS_PASSWORD" ]]; then
                print_error "Please enter a valid password"
            else
                print_question "Confirm Shadowsocks password: "
                read -rs SHADOWSOCKS_PASSWORD_CONFIRM
                echo ""

                if [[ "$SHADOWSOCKS_PASSWORD" != "$SHADOWSOCKS_PASSWORD_CONFIRM" ]]; then
                    print_error "Passwords do not match. Please try again."
                    SHADOWSOCKS_PASSWORD=""
                else
                    break
                fi
            fi
        done

        # Get encryption method
        echo "Select encryption method:"
        echo "1) aes-256-gcm (recommended)"
        echo "2) aes-128-gcm"
        echo "3) chacha20-ietf-poly1305"
        echo "4) aes-256-cfb"
        echo "5) aes-128-cfb"
        while true; do
            if [[ -n "${existing_ss_method:-}" ]]; then
                print_question "Enter choice (current: $existing_ss_method): "
            else
                print_question "Enter choice (default: 1): "
            fi
            read -r method_choice

            if [[ -z "$method_choice" ]]; then
                if [[ -n "${existing_ss_method:-}" ]]; then
                    SHADOWSOCKS_METHOD="$existing_ss_method"
                else
                    SHADOWSOCKS_METHOD="aes-256-gcm"
                fi
                break
            fi

            case $method_choice in
                1) SHADOWSOCKS_METHOD="aes-256-gcm"; break ;;
                2) SHADOWSOCKS_METHOD="aes-128-gcm"; break ;;
                3) SHADOWSOCKS_METHOD="chacha20-ietf-poly1305"; break ;;
                4) SHADOWSOCKS_METHOD="aes-256-cfb"; break ;;
                5) SHADOWSOCKS_METHOD="aes-128-cfb"; break ;;
                *) print_error "Invalid choice. Please enter 1-5" ;;
            esac
        done
    fi

    print_status "Configuration:"
    print_status "  Domain: $DOMAIN"
    print_status "  Tunnel mode: $TUNNEL_MODE"
    if [ "$TUNNEL_MODE" = "socks" ]; then
        if [ "$SOCKS_AUTH_ENABLED" = "yes" ]; then
            print_status "  SOCKS authentication: enabled (username: $SOCKS_USERNAME)"
        else
            print_status "  SOCKS authentication: disabled"
        fi
    fi
    if [ "$TUNNEL_MODE" = "shadowsocks" ]; then
        print_status "  Shadowsocks port: $SHADOWSOCKS_PORT"
        print_status "  Shadowsocks method: $SHADOWSOCKS_METHOD"
    fi
}

# Function to detect architecture and get asset name
get_asset_name() {
    local arch
    arch=$(uname -m)
    local os
    os=$(uname -s | tr '[:upper:]' '[:lower:]')

    case "$os" in
        linux)
            case "$arch" in
                x86_64|amd64)
                    echo "linux-amd64"
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        darwin)
            case "$arch" in
                arm64|aarch64)
                    echo "darwin-arm64"
                    return 0
                    ;;
                *)
                    return 1
                    ;;
            esac
            ;;
        *)
            return 1
            ;;
    esac
}

# Function to download prebuilt binary
download_prebuilt_binary() {
    local asset_name
    if ! asset_name=$(get_asset_name); then
        print_warning "No prebuilt binary available for this architecture"
        return 1
    fi

    print_status "Attempting to download prebuilt binary for $asset_name..."

    local binary_name="slipstream-server-${asset_name}"
    local temp_binary="/tmp/${binary_name}"
    local download_url=""
    local latest_tag=""

    print_status "Fetching latest release information..."
    local api_response
    api_response=$(curl -fsSL "https://api.github.com/repos/AliRezaBeigy/slipstream-rust-deploy/releases/latest" 2>/dev/null)
    
    if [ -n "$api_response" ]; then
        latest_tag=$(echo "$api_response" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
        if [ -n "$latest_tag" ]; then
            print_status "Found latest release tag: $latest_tag"
            download_url="https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/download/${latest_tag}/${binary_name}"
        fi
    fi

    if [ -z "$download_url" ]; then
        print_warning "Could not fetch release tag from API, trying /latest/download endpoint..."
        download_url="${RELEASE_URL}/${binary_name}"
    fi
    print_status "Downloading prebuilt slipstream-server binary from: $download_url"

    # Download the binary
    if curl -fsSL "$download_url" -o "$temp_binary" 2>/dev/null; then
        # Verify the download is a valid binary (not HTML error page)
        if file "$temp_binary" | grep -qE "(executable|ELF|Mach-O)"; then
            chmod +x "$temp_binary"
            cp "$temp_binary" "$INSTALL_DIR/slipstream-server"
            rm "$temp_binary"
            print_status "Successfully downloaded prebuilt slipstream-server binary"
            return 0
        else
            print_warning "Downloaded file is not a valid binary"
            rm -f "$temp_binary"
            return 1
        fi
    else
        print_warning "Failed to download prebuilt binary from release"
        return 1
    fi
}

# Function to build slipstream-rust from source
build_slipstream_rust() {
    print_status "Building slipstream-rust from source..."

    # Ensure cargo is in PATH
    if [ -f "$HOME/.cargo/env" ]; then
        source "$HOME/.cargo/env"
    elif [ -f "/root/.cargo/env" ]; then
        source "/root/.cargo/env"
    fi

    # Check if cargo is available
    if ! command -v cargo &> /dev/null; then
        print_error "cargo is not available. Please install Rust toolchain first."
        exit 1
    fi

    # Create build directory
    mkdir -p "$BUILD_DIR"
    cd "$BUILD_DIR"

    # Clone or update repository
    if [ -d "$BUILD_DIR/.git" ]; then
        print_status "Repository already exists, updating..."
        cd "$BUILD_DIR"
        git pull || print_warning "Failed to update repository, continuing with existing code..."
    else
        print_status "Cloning slipstream-rust repository..."
        if ! git clone "$REPO_URL" "$BUILD_DIR"; then
            print_error "Failed to clone repository"
            exit 1
        fi
    fi

    # Initialize and update submodules
    print_status "Initializing submodules..."
    cd "$BUILD_DIR"
    git submodule update --init --recursive

    # Build picoquic if needed
    print_status "Building picoquic dependencies..."
    if [ -f "$BUILD_DIR/scripts/build_picoquic.sh" ]; then
        bash "$BUILD_DIR/scripts/build_picoquic.sh"
    fi

    # Build slipstream-server
    print_status "Building slipstream-server (this may take several minutes)..."
    if ! cargo build --release -p slipstream-server; then
        print_error "Failed to build slipstream-server"
        exit 1
    fi

    # Copy binary to install directory
    if [ -f "$BUILD_DIR/target/release/slipstream-server" ]; then
        cp "$BUILD_DIR/target/release/slipstream-server" "$INSTALL_DIR/slipstream-server"
        chmod +x "$INSTALL_DIR/slipstream-server"
        print_status "slipstream-server built and installed successfully"
    else
        print_error "Built binary not found at expected location"
        exit 1
    fi
}

# Function to install slipstream-server (prebuilt or from source)
install_slipstream_server() {
    print_status "Installing slipstream-server..."

    # Stop the service if it's running to avoid "Text file busy" error when copying
    if systemctl is-active --quiet slipstream-rust-server 2>/dev/null; then
        print_status "Stopping existing slipstream-rust-server service for update..."
        systemctl stop slipstream-rust-server
    fi

    # First, try to download prebuilt binary
    if download_prebuilt_binary; then
        print_status "Using prebuilt binary - skipping build dependencies"
        return 0
    fi

    # Fall back to building from source
    print_status "Prebuilt binary not available, will build from source..."

    # Check and install required tools for building
    check_required_tools

    # Build from source
    build_slipstream_rust
}

# Function to create slipstream user
create_slipstream_user() {
    print_status "Creating slipstream user..."

    if ! id "$SLIPSTREAM_USER" &>/dev/null; then
        useradd -r -s /bin/false -d /nonexistent -c "slipstream service user" "$SLIPSTREAM_USER"
        print_status "Created user: $SLIPSTREAM_USER"
    else
        print_status "User $SLIPSTREAM_USER already exists"
    fi

    # Create config directory first
    mkdir -p "$CONFIG_DIR"

    # Set ownership of config directory
    chown -R "$SLIPSTREAM_USER":"$SLIPSTREAM_USER" "$CONFIG_DIR"
    chmod 750 "$CONFIG_DIR"
}

# Function to generate TLS certificates
generate_certificates() {
    # Generate certificate file names based on domain
    local cert_prefix
    # shellcheck disable=SC2001
    cert_prefix=$(echo "$DOMAIN" | sed 's/\./_/g')
    CERT_FILE="${CONFIG_DIR}/${cert_prefix}_cert.pem"
    KEY_FILE="${CONFIG_DIR}/${cert_prefix}_key.pem"

    # Check if certificates already exist for this domain
    if [[ -f "$CERT_FILE" && -f "$KEY_FILE" ]]; then
        print_status "Found existing certificates for domain: $DOMAIN"
        print_status "  Certificate: $CERT_FILE"
        print_status "  Key: $KEY_FILE"

        # Verify certificate ownership and permissions
        chown "$SLIPSTREAM_USER":"$SLIPSTREAM_USER" "$CERT_FILE" "$KEY_FILE"
        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"

        print_status "Using existing certificates (verified ownership and permissions)"
    else
        print_status "Generating new TLS certificates for domain: $DOMAIN"

        # Generate certificates (run as root, then change ownership)
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout "$KEY_FILE" \
            -out "$CERT_FILE" \
            -days 365 \
            -subj "/CN=slipstream"

        # Set proper ownership and permissions
        chown "$SLIPSTREAM_USER":"$SLIPSTREAM_USER" "$CERT_FILE" "$KEY_FILE"
        chmod 644 "$CERT_FILE"
        chmod 600 "$KEY_FILE"

        print_status "New certificates generated:"
        print_status "  Certificate: $CERT_FILE"
        print_status "  Key: $KEY_FILE"
    fi
}

# Function to configure iptables rules
configure_iptables() {
    print_status "Configuring iptables rules for DNS redirection..."

    # Verify iptables is available
    if ! command -v iptables &> /dev/null; then
        print_error "iptables command not found. Cannot configure firewall rules."
        exit 1
    fi

    # Get the primary network interface
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$interface" ]]; then
        # Try alternative method to get interface
        interface=$(ip link show | grep -E "^[0-9]+: (eth|ens|enp)" | head -1 | cut -d':' -f2 | awk '{print $1}')
        if [[ -z "$interface" ]]; then
            interface="eth0"  # fallback
            print_warning "Could not detect network interface, using eth0 as fallback"
        else
            print_status "Detected network interface: $interface"
        fi
    else
        print_status "Using network interface: $interface"
    fi

    # IPv4 rules
    print_status "Setting up IPv4 iptables rules..."

    if ! iptables -I INPUT -p udp --dport "$SLIPSTREAM_PORT" -j ACCEPT; then
        print_error "Failed to add IPv4 INPUT rule"
        exit 1
    fi

    if ! iptables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports "$SLIPSTREAM_PORT"; then
        print_error "Failed to add IPv4 NAT rule"
        exit 1
    fi

    print_status "IPv4 iptables rules configured successfully"

    # IPv6 rules (if IPv6 and ip6tables are available)
    if command -v ip6tables &> /dev/null && [ -f /proc/net/if_inet6 ]; then
        print_status "Setting up IPv6 iptables rules..."

        if ip6tables -I INPUT -p udp --dport "$SLIPSTREAM_PORT" -j ACCEPT 2>/dev/null; then
            print_status "IPv6 INPUT rule added successfully"
        else
            print_warning "Failed to add IPv6 INPUT rule (IPv6 might not be fully configured)"
        fi

        if ip6tables -t nat -I PREROUTING -i "$interface" -p udp --dport 53 -j REDIRECT --to-ports "$SLIPSTREAM_PORT" 2>/dev/null; then
            print_status "IPv6 NAT rule added successfully"
        else
            print_warning "Failed to add IPv6 NAT rule (IPv6 NAT might not be supported)"
        fi
    else
        if ! command -v ip6tables &> /dev/null; then
            print_warning "ip6tables not available, skipping IPv6 rules"
        elif [ ! -f /proc/net/if_inet6 ]; then
            print_warning "IPv6 not enabled on system, skipping IPv6 rules"
        fi
    fi

    # Save iptables rules based on distribution
    save_iptables_rules
}

# Function to save iptables rules with better error handling
save_iptables_rules() {
    print_status "Saving iptables rules..."

    case $PKG_MANAGER in
        dnf|yum)
            # For RHEL-based systems
            if command -v iptables-save &> /dev/null; then
                # Create directory if it doesn't exist
                mkdir -p /etc/sysconfig

                if iptables-save > /etc/sysconfig/iptables; then
                    print_status "IPv4 iptables rules saved to /etc/sysconfig/iptables"
                else
                    print_warning "Failed to save IPv4 iptables rules"
                fi

                if command -v ip6tables-save &> /dev/null && [ -f /proc/net/if_inet6 ]; then
                    if ip6tables-save > /etc/sysconfig/ip6tables; then
                        print_status "IPv6 iptables rules saved to /etc/sysconfig/ip6tables"
                    else
                        print_warning "Failed to save IPv6 iptables rules"
                    fi
                fi

                # Enable and start iptables service if available
                if systemctl list-unit-files | grep -q iptables.service; then
                    systemctl enable iptables 2>/dev/null || print_warning "Could not enable iptables service"
                    if command -v ip6tables &> /dev/null && [ -f /proc/net/if_inet6 ]; then
                        systemctl enable ip6tables 2>/dev/null || print_warning "Could not enable ip6tables service"
                    fi
                fi
            else
                print_warning "iptables-save not available, rules will not persist after reboot"
            fi
            ;;
        apt)
            # For Debian-based systems
            if command -v iptables-save &> /dev/null; then
                # Create directory if it doesn't exist
                mkdir -p /etc/iptables

                if iptables-save > /etc/iptables/rules.v4; then
                    print_status "IPv4 iptables rules saved to /etc/iptables/rules.v4"
                else
                    print_warning "Failed to save IPv4 iptables rules"
                fi

                if command -v ip6tables-save &> /dev/null && [ -f /proc/net/if_inet6 ]; then
                    if ip6tables-save > /etc/iptables/rules.v6; then
                        print_status "IPv6 iptables rules saved to /etc/iptables/rules.v6"
                    else
                        print_warning "Failed to save IPv6 iptables rules"
                    fi
                fi

                # Try to enable netfilter-persistent if available
                if systemctl list-unit-files | grep -q netfilter-persistent.service; then
                    systemctl enable netfilter-persistent 2>/dev/null || print_warning "Could not enable netfilter-persistent service"
                fi
            else
                print_warning "iptables-save not available, rules will not persist after reboot"
            fi
            ;;
    esac
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."

    # Check if firewalld is available and active
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        print_status "Configuring active firewalld..."
        firewall-cmd --permanent --add-port="$SLIPSTREAM_PORT"/udp
        firewall-cmd --permanent --add-port=53/udp
        firewall-cmd --reload
        print_status "Firewalld configured successfully"

    # Check if ufw is available and active
    elif command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        print_status "Configuring active ufw..."
        ufw allow "$SLIPSTREAM_PORT"/udp
        ufw allow 53/udp
        print_status "UFW configured successfully"

    else
        print_status "No active firewall service detected"
        print_status "Available firewall tools:"

        # List available but inactive firewall tools
        if command -v firewall-cmd &> /dev/null; then
            print_status "  - firewalld (inactive)"
        fi
        if command -v ufw &> /dev/null; then
            print_status "  - ufw (inactive)"
        fi

        print_status "Relying on iptables rules only"
        print_status "If you have a firewall active, manually allow ports $SLIPSTREAM_PORT/udp and 53/udp"
    fi

    # Configure iptables rules regardless of firewall service
    configure_iptables
}

# Function to detect SSH port
detect_ssh_port() {
    local ssh_port
    ssh_port=$(ss -tlnp | grep sshd | awk '{print $4}' | cut -d':' -f2 | head -1)
    if [[ -z "$ssh_port" ]]; then
        # Fallback to default SSH port
        ssh_port="22"
    fi
    echo "$ssh_port"
}

# Function to install and configure Dante SOCKS proxy
setup_dante() {
    print_status "Setting up Dante SOCKS proxy..."

    # Install Dante
    case $PKG_MANAGER in
        dnf|yum)
            $PKG_MANAGER install -y dante-server
            ;;
        apt)
            apt install -y dante-server
            ;;
    esac

    # Get the primary network interface for external interface
    local external_interface
    external_interface=$(ip route | grep default | awk '{print $5}' | head -1)
    if [[ -z "$external_interface" ]]; then
        external_interface="eth0"  # fallback
    fi

    local socks_method="none"
    
    if [[ "${SOCKS_AUTH_ENABLED:-no}" == "yes" && -n "${SOCKS_USERNAME:-}" && -n "${SOCKS_PASSWORD:-}" ]]; then
        socks_method="username"
        
        if ! id "$SOCKS_USERNAME" &>/dev/null; then
            print_status "Creating system user for SOCKS authentication: $SOCKS_USERNAME"
            useradd -r -s /bin/false -M "$SOCKS_USERNAME" 2>/dev/null || {
                print_error "Failed to create system user: $SOCKS_USERNAME"
                return 1
            }
            print_status "System user created: $SOCKS_USERNAME"
        else
            print_status "System user already exists: $SOCKS_USERNAME"
        fi
        
        print_status "Setting password for SOCKS user: $SOCKS_USERNAME"
        echo "$SOCKS_USERNAME:$SOCKS_PASSWORD" | chpasswd 2>/dev/null || {
            print_error "Failed to set password for user: $SOCKS_USERNAME"
            return 1
        }
        print_status "Password set successfully for SOCKS user"
    fi

    # Configure Dante
    cat > /etc/danted.conf << EOF
# Dante SOCKS server configuration
logoutput: syslog
user.privileged: root
user.unprivileged: nobody

# Internal interface (where clients connect)
internal: 127.0.0.1 port = 1080

# External interface (where connections go out)
external: $external_interface

# Authentication method
socksmethod: $socks_method
EOF

    cat >> /etc/danted.conf << EOF

# Compatibility settings
compatibility: sameport
extension: bind

# Client rules - allow connections from localhost
client pass {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    log: error
}

# SOCKS rules - allow SOCKS requests to anywhere
socks pass {
    from: 127.0.0.0/8 to: 0.0.0.0/0
    command: bind connect udpassociate
EOF

    if [[ -n "$passwd_file" ]]; then
        cat >> /etc/danted.conf << EOF
    method: username
EOF
    fi

    cat >> /etc/danted.conf << EOF
    log: error
}

# Block IPv6 if not properly configured
socks block {
    from: 0.0.0.0/0 to: ::/0
    log: error
}

client block {
    from: 0.0.0.0/0 to: ::/0
    log: error
}
EOF

    # Enable and start Dante service
    systemctl enable danted
    systemctl restart danted

    print_status "Dante SOCKS proxy configured and started on port 1080"
    print_status "External interface: $external_interface"
    if [[ "$socks_method" == "username" ]]; then
        print_status "SOCKS authentication: enabled (username: $SOCKS_USERNAME)"
    else
        print_status "SOCKS authentication: disabled"
    fi
}

# Function to install and configure Shadowsocks
setup_shadowsocks() {
    print_status "Setting up Shadowsocks..."

    local shadowsocks_installed=false

    # First, try snap (recommended method)
    if command -v snap &> /dev/null; then
        print_status "Attempting to install shadowsocks-libev via snap..."
        if snap install shadowsocks-libev 2>/dev/null; then
            shadowsocks_installed=true
            print_status "Successfully installed shadowsocks-libev via snap"
        else
            print_warning "Failed to install shadowsocks-libev via snap, trying package manager..."
        fi
    else
        print_status "snap not available, trying package manager..."
    fi

    # If snap failed or not available, try package manager
    if [ "$shadowsocks_installed" = false ]; then
        case $PKG_MANAGER in
            dnf|yum)
                print_status "Attempting to install shadowsocks-libev via $PKG_MANAGER..."
                # Enable EPEL repository for shadowsocks-libev
                $PKG_MANAGER install -y epel-release 2>/dev/null || true
                if $PKG_MANAGER install -y shadowsocks-libev; then
                    shadowsocks_installed=true
                    print_status "Successfully installed shadowsocks-libev via $PKG_MANAGER"
                else
                    print_error "Failed to install shadowsocks-libev via $PKG_MANAGER"
                fi
                ;;
            apt)
                print_status "Attempting to install shadowsocks-libev via apt..."
                if apt update && apt install -y shadowsocks-libev; then
                    shadowsocks_installed=true
                    print_status "Successfully installed shadowsocks-libev via apt"
                else
                    print_error "Failed to install shadowsocks-libev via apt"
                fi
                ;;
            *)
                print_error "Unsupported package manager: $PKG_MANAGER"
                ;;
        esac
    fi

    # If installation failed, exit with error
    if [ "$shadowsocks_installed" = false ]; then
        print_error "Failed to install shadowsocks-libev via snap or package manager"
        print_error "Please install shadowsocks-libev manually and try again"
        exit 1
    fi

    # Create Shadowsocks configuration directory
    mkdir -p /etc/shadowsocks-libev

    # Create Shadowsocks configuration file
    cat > /etc/shadowsocks-libev/config.json << EOF
{
    "server": "127.0.0.1",
    "server_port": ${SHADOWSOCKS_PORT},
    "password": "${SHADOWSOCKS_PASSWORD}",
    "timeout": 300,
    "method": "${SHADOWSOCKS_METHOD}",
    "fast_open": false,
    "mode": "tcp_only"
}
EOF

    # Set permissions to 644 so the DynamicUser in systemd can read it
    chmod 644 /etc/shadowsocks-libev/config.json
    chown root:root /etc/shadowsocks-libev/config.json

    # Create systemd service override if needed (for snap installations)
    local service_created=false
    if command -v snap &> /dev/null && snap list shadowsocks-libev &>/dev/null; then
        local snap_bin
        snap_bin=$(command -v snap)
        if [ -z "$snap_bin" ]; then
            snap_bin="/usr/bin/snap"
        fi
        
        # For snap installation, create a wrapper service
        cat > /etc/systemd/system/shadowsocks-libev-server@config.service << EOF
[Unit]
Description=Shadowsocks-libev Server Service for %i
After=network.target

[Service]
Type=simple
ExecStart=${snap_bin} run shadowsocks-libev.ss-server -c /etc/shadowsocks-libev/%i.json
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
        systemctl daemon-reload
        service_created=true
    fi

    # Enable and start Shadowsocks service
    if [ "$service_created" = true ] || [ -f /etc/systemd/system/shadowsocks-libev-server@config.service ]; then
        systemctl enable shadowsocks-libev-server@config
        systemctl restart shadowsocks-libev-server@config
        if ! systemctl is-active --quiet shadowsocks-libev-server@config; then
            print_error "Shadowsocks service failed to start"
            print_status "Check logs with: journalctl -u shadowsocks-libev-server@config -n 50"
            exit 1
        fi
    elif systemctl list-unit-files | grep -q "shadowsocks-libev-server@.service"; then
        systemctl enable shadowsocks-libev-server@config
        systemctl restart shadowsocks-libev-server@config
        if ! systemctl is-active --quiet shadowsocks-libev-server@config; then
            print_error "Shadowsocks service failed to start"
            print_status "Check logs with: journalctl -u shadowsocks-libev-server@config -n 50"
            exit 1
        fi
    elif systemctl list-unit-files | grep -q "shadowsocks-libev.service"; then
        # Some distros use a different service name
        systemctl enable shadowsocks-libev
        systemctl restart shadowsocks-libev
        if ! systemctl is-active --quiet shadowsocks-libev; then
            print_error "Shadowsocks service failed to start"
            print_status "Check logs with: journalctl -u shadowsocks-libev -n 50"
            exit 1
        fi
    else
        print_error "Could not find Shadowsocks systemd service"
        exit 1
    fi

    print_status "Shadowsocks configured and started on port $SHADOWSOCKS_PORT"
    print_status "Encryption method: $SHADOWSOCKS_METHOD"
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."

    local service_name="slipstream-rust-server"
    local service_file="${SYSTEMD_DIR}/${service_name}.service"
    local target_port

    case "$TUNNEL_MODE" in
        ssh)
            target_port=$(detect_ssh_port)
            print_status "Detected SSH port: $target_port"
            ;;
        shadowsocks)
            target_port="${SHADOWSOCKS_PORT:-8388}"
            print_status "Using Shadowsocks port: $target_port"
            ;;
        socks|*)
            target_port="1080"  # Dante SOCKS port
            ;;
    esac

    # Stop service if it's running to allow reconfiguration
    if systemctl is-active --quiet "$service_name"; then
        print_status "Stopping existing slipstream-rust-server service for reconfiguration..."
        systemctl stop "$service_name"
    fi

    local dns_listen_host="0.0.0.0"
    if command -v ip6tables &> /dev/null && [ -f /proc/net/if_inet6 ]; then
        if ip -6 addr show | grep -q "inet6"; then
            dns_listen_host="::"
            print_status "IPv6 detected, using :: for dual-stack support"
        else
            print_status "IPv6 not configured, using 0.0.0.0 for IPv4 only"
        fi
    else
        print_status "IPv6 not available, using 0.0.0.0 for IPv4 only"
    fi

    # Create systemd service file
    cat > "$service_file" << EOF
[Unit]
Description=slipstream-rust DNS Tunnel Server
After=network.target
Wants=network.target

[Service]
Type=simple
User=$SLIPSTREAM_USER
Group=$SLIPSTREAM_USER
ExecStart=${INSTALL_DIR}/slipstream-server --dns-listen-host ${dns_listen_host} --dns-listen-port ${SLIPSTREAM_PORT} --target-address 127.0.0.1:${target_port} --domain ${DOMAIN} --cert ${CERT_FILE} --key ${KEY_FILE}
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5
# Restart service every 60 minutes to work around server memory/state bugs
RuntimeMaxSec=3600

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/
ReadWritePaths=${CONFIG_DIR}
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$service_name"

    print_status "Systemd service created: $service_name"
    print_status "Service will run as user: $SLIPSTREAM_USER"
    print_status "Service will listen on port: $SLIPSTREAM_PORT (redirected from port 53)"
    print_status "Service will tunnel to 127.0.0.1:$target_port"
    print_status "Mode: $TUNNEL_MODE"
}

# Function to start services
start_services() {
    print_status "Starting services..."

    # Start slipstream-rust-server service
    systemctl start slipstream-rust-server

    print_status "slipstream-rust-server service started"

    # Show service status
    systemctl status slipstream-rust-server --no-pager -l
}

# Function to print success box without [INFO] prefix
print_success_box() {
    local border_color='\033[1;32m'  # Bright green
    local text_color='\033[1;37m'    # Bright white text
    local key_color='\033[1;33m'     # Yellow for key
    local header_color='\033[1;36m'  # Cyan for headers
    local reset='\033[0m'

    echo ""
    # Top border
    echo -e "${border_color}+================================================================================${reset}"
    echo -e "${border_color}|                          SETUP COMPLETED SUCCESSFULLY!                       |${reset}"
    echo -e "${border_color}+================================================================================${reset}"
    echo ""

    # Configuration Details
    echo -e "${header_color}Configuration Details:${reset}"
    echo -e "  ${text_color}Domain: $DOMAIN${reset}"
    echo -e "  ${text_color}Tunnel mode: $TUNNEL_MODE${reset}"
    echo -e "  ${text_color}Service user: $SLIPSTREAM_USER${reset}"
    echo -e "  ${text_color}Listen port: $SLIPSTREAM_PORT (DNS traffic redirected from port 53)${reset}"
    echo ""

    # Script Location
    echo -e "${text_color}Script installed at: $SCRIPT_INSTALL_PATH${reset}"
    echo ""

    # Management Commands
    echo -e "${header_color}Management Commands:${reset}"
    echo -e "  ${text_color}Run menu:           slipstream-rust-deploy${reset}"
    echo -e "  ${text_color}Start service:      systemctl start slipstream-rust-server${reset}"
    echo -e "  ${text_color}Stop service:       systemctl stop slipstream-rust-server${reset}"
    echo -e "  ${text_color}Service status:     systemctl status slipstream-rust-server${reset}"
    echo -e "  ${text_color}View logs:          journalctl -u slipstream-rust-server -f${reset}"

    # SOCKS info if applicable
    if [ "$TUNNEL_MODE" = "socks" ]; then
        echo ""
        echo -e "${header_color}SOCKS Proxy Information:${reset}"
        echo -e "${text_color}SOCKS proxy is running on 127.0.0.1:1080${reset}"
        if [[ "${SOCKS_AUTH_ENABLED:-no}" == "yes" && -n "${SOCKS_USERNAME:-}" ]]; then
            echo -e "${text_color}Authentication: ${key_color}Enabled${reset} (username: ${key_color}$SOCKS_USERNAME${reset})"
        else
            echo -e "${text_color}Authentication: ${key_color}Disabled${reset}"
        fi
        echo -e "${text_color}Dante service commands:${reset}"
        echo -e "  ${text_color}Status:  systemctl status danted${reset}"
        echo -e "  ${text_color}Stop:    systemctl stop danted${reset}"
        echo -e "  ${text_color}Start:   systemctl start danted${reset}"
        echo -e "  ${text_color}Logs:    journalctl -u danted -f${reset}"
    fi

    # Shadowsocks info if applicable
    if [ "$TUNNEL_MODE" = "shadowsocks" ]; then
        echo ""
        echo -e "${header_color}Shadowsocks Information:${reset}"
        echo -e "${text_color}Shadowsocks server is running on 127.0.0.1:${SHADOWSOCKS_PORT:-8388}${reset}"
        echo -e "${text_color}Encryption method: ${key_color}${SHADOWSOCKS_METHOD:-aes-256-gcm}${reset}"
        echo -e "${text_color}Shadowsocks service commands:${reset}"
        echo -e "  ${text_color}Status:  systemctl status shadowsocks-libev-server@config${reset}"
        echo -e "  ${text_color}Stop:    systemctl stop shadowsocks-libev-server@config${reset}"
        echo -e "  ${text_color}Start:   systemctl start shadowsocks-libev-server@config${reset}"
        echo -e "  ${text_color}Logs:    journalctl -u shadowsocks-libev-server@config -f${reset}"
    fi

    # Bottom border
    echo ""
    echo -e "${border_color}+================================================================================${reset}"
    echo ""
}

# Function to display final information
display_final_info() {
    print_success_box
}

# Function to detect dnstt installation
detect_dnstt() {
    local dnstt_detected=false
    local detection_reasons=()

    # Check for dnstt-server binary
    if [ -f "/usr/local/bin/dnstt-server" ]; then
        dnstt_detected=true
        detection_reasons+=("dnstt-server binary found at /usr/local/bin/dnstt-server")
    fi

    # Check for dnstt-server systemd service
    if systemctl list-unit-files | grep -q "^dnstt-server.service"; then
        dnstt_detected=true
        detection_reasons+=("dnstt-server systemd service found")
    fi

    # Check for dnstt user
    if id "dnstt" &>/dev/null; then
        dnstt_detected=true
        detection_reasons+=("dnstt user found")
    fi

    # Check for dnstt config directory
    if [ -d "/etc/dnstt" ]; then
        dnstt_detected=true
        detection_reasons+=("dnstt config directory found at /etc/dnstt")
    fi

    # Check for dnstt-deploy script
    if [ -f "/usr/local/bin/dnstt-deploy" ]; then
        dnstt_detected=true
        detection_reasons+=("dnstt-deploy script found")
    fi

    if [ "$dnstt_detected" = true ]; then
        echo ""
        print_error "dnstt installation detected on this system!"
        echo ""
        print_warning "The following dnstt components were found:"
        for reason in "${detection_reasons[@]}"; do
            echo -e "  ${YELLOW}- $reason${NC}"
        done
        echo ""
        print_warning "dnstt must be uninstalled before installing slipstream-rust."
        print_warning "Both services use port 5300 and will conflict."
        echo ""
        print_status "To uninstall dnstt, run the following command:"
        echo -e "${GREEN}  bash <(curl -Ls https://raw.githubusercontent.com/AliRezaBeigy/dnstt-deploy/main/dnstt-deploy.sh) uninstall${NC}"
        echo ""
        print_question "Press Enter after uninstalling dnstt to continue, or Ctrl+C to exit: "
        read -r
        echo ""
        
        # Verify dnstt is actually uninstalled
        local still_installed=false
        if [ -f "/usr/local/bin/dnstt-server" ] || \
           systemctl list-unit-files | grep -q "^dnstt-server.service" || \
           id "dnstt" &>/dev/null || \
           [ -d "/etc/dnstt" ]; then
            still_installed=true
        fi
        
        if [ "$still_installed" = true ]; then
            print_error "dnstt is still detected on the system. Please uninstall it completely before proceeding."
            exit 1
        else
            print_status "dnstt has been successfully removed. Continuing with slipstream-rust installation..."
        fi
    fi
}

# Main function
main() {
    # Handle command-line arguments
    if [ "$1" = "uninstall" ]; then
        uninstall_slipstream
        exit $?
    fi

    # If not running from installed location (curl/GitHub), install the script first
    if [ "$0" != "$SCRIPT_INSTALL_PATH" ]; then
        print_status "Installing slipstream-rust-deploy script..."
        install_script
        print_status "Starting slipstream-rust server setup..."
    else
        # Running from installed location - check for updates and show menu
        check_for_updates
        handle_menu
        # If we reach here, user chose option 1 (Install/Reconfigure), so continue
        print_status "Starting slipstream-rust server installation/reconfiguration..."
    fi

    # Detect OS and architecture
    detect_os

    # Check for dnstt installation and notify user if found
    detect_dnstt

    # Get user input
    get_user_input

    # Install slipstream-server (prebuilt or from source)
    install_slipstream_server

    # Create slipstream user
    create_slipstream_user

    # Generate certificates
    generate_certificates

    # Save configuration after certificates are generated
    save_config

    # Configure firewall and iptables
    configure_firewall

    # Setup tunnel mode specific configurations
    case "$TUNNEL_MODE" in
        socks)
            setup_dante
            # Stop Shadowsocks if it was running
            if systemctl is-active --quiet shadowsocks-libev-server@config 2>/dev/null; then
                print_status "Switching to SOCKS mode - stopping Shadowsocks service..."
                systemctl stop shadowsocks-libev-server@config
                systemctl disable shadowsocks-libev-server@config
            fi
            ;;
        shadowsocks)
            setup_shadowsocks
            # Stop Dante if it was running
            if systemctl is-active --quiet danted 2>/dev/null; then
                print_status "Switching to Shadowsocks mode - stopping Dante service..."
                systemctl stop danted
                systemctl disable danted
            fi
            ;;
        ssh|*)
            # If switching from SOCKS or Shadowsocks to SSH, stop those services
            if systemctl is-active --quiet danted 2>/dev/null; then
                print_status "Switching to SSH mode - stopping Dante service..."
                systemctl stop danted
                systemctl disable danted
            fi
            if systemctl is-active --quiet shadowsocks-libev-server@config 2>/dev/null; then
                print_status "Switching to SSH mode - stopping Shadowsocks service..."
                systemctl stop shadowsocks-libev-server@config
                systemctl disable shadowsocks-libev-server@config
            fi
            ;;
    esac

    # Create systemd service
    create_systemd_service

    # Start services
    start_services

    # Display final information
    display_final_info
}

# Run main function
main "$@"
