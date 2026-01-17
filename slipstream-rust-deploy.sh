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
    echo "0) Exit"
    echo ""
    print_question "Please select an option (0-5): "
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
            0)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Please enter 0-5."
                ;;
        esac

        if [ "$choice" != "4" ]; then
            echo ""
            print_question "Press Enter to continue..."
            read -r
        fi
    done
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
        echo -e "${BLUE}Dante service commands:${NC}"
        echo -e "  Status:  ${YELLOW}systemctl status danted${NC}"
        echo -e "  Stop:    ${YELLOW}systemctl stop danted${NC}"
        echo -e "  Start:   ${YELLOW}systemctl start danted${NC}"
        echo -e "  Logs:    ${YELLOW}journalctl -u danted -f${NC}"
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
    # Load existing configuration if available
    local existing_domain=""
    local existing_mode=""

    if load_existing_config; then
        existing_domain="$DOMAIN"
        existing_mode="$TUNNEL_MODE"
        print_status "Found existing configuration for domain: $existing_domain"
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
        echo "1) SOCKS proxy"
        echo "2) SSH mode"
        if [[ -n "$existing_mode" ]]; then
            local mode_number
            if [[ "$existing_mode" == "socks" ]]; then
                mode_number="1"
            else
                mode_number="2"
            fi
            print_question "Enter choice (current: $mode_number - $existing_mode): "
        else
            print_question "Enter choice (1 or 2): "
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
            *)
                print_error "Invalid choice. Please enter 1 or 2"
                ;;
        esac
    done

    print_status "Configuration:"
    print_status "  Domain: $DOMAIN"
    print_status "  Tunnel mode: $TUNNEL_MODE"
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
socksmethod: none

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
}

# Function to create systemd service
create_systemd_service() {
    print_status "Creating systemd service..."

    local service_name="slipstream-rust-server"
    local service_file="${SYSTEMD_DIR}/${service_name}.service"
    local target_port

    if [ "$TUNNEL_MODE" = "ssh" ]; then
        target_port=$(detect_ssh_port)
        print_status "Detected SSH port: $target_port"
    else
        target_port="1080"  # Dante SOCKS port
    fi

    # Stop service if it's running to allow reconfiguration
    if systemctl is-active --quiet "$service_name"; then
        print_status "Stopping existing slipstream-rust-server service for reconfiguration..."
        systemctl stop "$service_name"
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
ExecStart=${INSTALL_DIR}/slipstream-server --dns-listen-port ${SLIPSTREAM_PORT} --target-address 127.0.0.1:${target_port} --domain ${DOMAIN} --cert ${CERT_FILE} --key ${KEY_FILE}
Restart=always
RestartSec=5
KillMode=mixed
TimeoutStopSec=5

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
        echo -e "${text_color}Dante service commands:${reset}"
        echo -e "  ${text_color}Status:  systemctl status danted${reset}"
        echo -e "  ${text_color}Stop:    systemctl stop danted${reset}"
        echo -e "  ${text_color}Start:   systemctl start danted${reset}"
        echo -e "  ${text_color}Logs:    journalctl -u danted -f${reset}"
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

# Main function
main() {
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

    # Check and install required tools
    check_required_tools

    # Get user input
    get_user_input

    # Build slipstream-rust from source
    build_slipstream_rust

    # Create slipstream user
    create_slipstream_user

    # Generate certificates
    generate_certificates

    # Save configuration after certificates are generated
    save_config

    # Configure firewall and iptables
    configure_firewall

    # Setup tunnel mode specific configurations
    if [ "$TUNNEL_MODE" = "socks" ]; then
        setup_dante
    else
        # If switching from SOCKS to SSH, stop and disable Dante
        if systemctl is-active --quiet danted; then
            print_status "Switching from SOCKS to SSH mode - stopping Dante service..."
            systemctl stop danted
            systemctl disable danted
        fi
    fi

    # Create systemd service
    create_systemd_service

    # Start services
    start_services

    # Display final information
    display_final_info
}

# Run main function
main "$@"
