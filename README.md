# Slipstream (Rust) Deploy Script

🚀 **One-click slipstream-rust server deployment and management**

A comprehensive automation script for deploying and managing [slipstream-rust](https://github.com/Mygod/slipstream-rust) DNS tunnel servers on Linux systems. This script handles everything from building from source to configuration, making DNS tunnel deployment effortless.

## DNS Domain Setup

Before using this script, you need to properly configure your domain's DNS records. Here's the required setup:

### Example Configuration
- **Your domain name**: `example.com`
- **Your server's IPv4 address**: `203.0.113.2`
- **Tunnel subdomain**: `s.example.com`
- **Server hostname**: `ns.example.com`

### DNS Records Setup
Go into your name registrar's configuration panel and add these records:

| Type | Name | Points to |
|------|------|-----------|
| A | `ns.example.com` | `203.0.113.2` |
| NS | `s.example.com` | `ns.example.com` |

**Important**: Wait for DNS propagation (can take up to 24 hours) before testing your tunnel.

## Features

- **Multi-distribution support**: Fedora, Rocky Linux, CentOS, Debian, Ubuntu
- **Interactive management menu**: Easy-to-use interface for all operations
- **Self-updating capability**: Built-in update mechanism for the script
- **Automatic detection**: OS and SSH port detection
- **Source build**: Automatically builds slipstream-rust from source (no pre-built binaries required)
- **Systemd service integration**: Creates and manages a dedicated systemd service for reliable operation, automatic startup on boot, and comprehensive logging
- **Security hardened**: Non-root service execution with systemd security features
- **Smart configuration**: Persistent settings and automatic certificate reuse
- **Flexible tunneling**: SSH mode or SOCKS proxy mode
- **Network ready**: Automatic firewall and iptables configuration
- **TLS certificates**: Automatic generation and management of TLS certificates

## Quick Start

### Prerequisites
- Linux server (Fedora, Rocky, CentOS, Debian, or Ubuntu)
- Root access or sudo privileges
- Internet connection for package downloads and building from source
- **Domain name with proper DNS configuration** (see DNS Domain Setup section above)
- **Build dependencies**: The script will automatically install Rust toolchain, cmake, pkg-config, and OpenSSL development headers

### Installation

**One-command installation:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/AliRezaBeigy/slipstream-rust-deploy/master/slipstream-rust-deploy.sh)
```

This command will:
1. Download and install the script to `/usr/local/bin/slipstream-rust-deploy`
2. Install all required build dependencies (Rust, cmake, pkg-config, OpenSSL)
3. Clone and build slipstream-rust from source
4. Start the interactive setup process
5. Configure your slipstream-rust server automatically

**Note**: The initial build process may take 10-30 minutes depending on your server's CPU and network speed.

### Post-Installation Usage

After installation, you can manage your slipstream-rust server using the installed command:

```bash
slipstream-rust-deploy
```

This will show an interactive menu with these options:

1. **Install/Reconfigure slipstream-rust server** - Set up or modify configuration
2. **Update slipstream-rust-deploy script** - Check for and install script updates
3. **Check service status** - View current service status
4. **View service logs** - Monitor real-time logs (Ctrl+C to exit)
5. **Show configuration info** - Display current configuration details
0. **Exit** - Quit the menu

### Setup Process

During the setup (option 1), you'll be prompted for:
- **Domain** (e.g., `example.com`)
- **Tunnel mode** (SSH or SOCKS)

The script will automatically:
- Generate TLS certificates if they don't exist
- Configure firewall and iptables rules
- Set up the appropriate tunnel mode (Dante SOCKS or SSH)
- Create and start the systemd service

## Configuration

### Tunnel Modes

**SOCKS Mode (Option 1)**
- Sets up integrated Dante SOCKS5 proxy
- Listens on `127.0.0.1:1080`
- Provides full internet proxy capabilities

**SSH Mode (Option 2)**
- Tunnels DNS traffic to your SSH service
- Automatically detects SSH port (default: 22)
- Perfect for secure shell access via DNS
- Compatible with mobile apps

### Changing Settings
To change settings:
1. Run `slipstream-rust-deploy`
2. Choose option 1 (Install/Reconfigure slipstream-rust server)
3. Enter new values when prompted

The script will automatically update the configuration and restart services.

## Management

### Management Menu

The easiest way to manage your slipstream-rust server is through the interactive menu:

```bash
slipstream-rust-deploy
```

This provides quick access to:
- Server reconfiguration
- Script updates
- Service status monitoring
- Real-time log viewing
- Configuration information

### File Locations

```
/usr/local/bin/slipstream-rust-deploy          # Management script
/usr/local/bin/slipstream-server               # Main binary (built from source)
/opt/slipstream-rust/                          # Source code and build directory
/etc/slipstream-rust/                          # Configuration directory
├── slipstream-rust-server.conf               # Main configuration
├── {domain}_cert.pem                         # TLS certificate (per domain)
└── {domain}_key.pem                          # TLS private key (per domain)
/etc/systemd/system/slipstream-rust-server.service  # Systemd service
```

### Manual Service Commands

If you prefer command-line management:

**slipstream-rust-server Service**:
```bash
sudo systemctl status slipstream-rust-server    # Check status
sudo systemctl start slipstream-rust-server     # Start service
sudo systemctl stop slipstream-rust-server      # Stop service
sudo systemctl restart slipstream-rust-server   # Restart service
sudo journalctl -u slipstream-rust-server -f    # View logs
```

**Dante SOCKS Service (SOCKS mode only)**:
```bash
sudo systemctl status danted          # Check status
sudo systemctl start danted           # Start service
sudo systemctl stop danted            # Stop service
sudo systemctl restart danted         # Restart service
sudo journalctl -u danted -f          # View logs
```

### Updating the Script

The script can update itself in two ways:

**Method 1: Using the menu (recommended)**
```bash
slipstream-rust-deploy
# Choose option 2: Update slipstream-rust-deploy script
```

**Method 2: Re-run the curl command**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/AliRezaBeigy/slipstream-rust-deploy/master/slipstream-rust-deploy.sh)
# The script will detect and install updates automatically
```

### Rebuilding from Source

If you need to rebuild slipstream-rust from source (e.g., after updating the repository):

```bash
slipstream-rust-deploy
# Choose option 1: Install/Reconfigure slipstream-rust server
# The script will automatically update the repository and rebuild
```

Or manually:
```bash
cd /opt/slipstream-rust
git pull
git submodule update --init --recursive
cargo build --release -p slipstream-server
sudo cp target/release/slipstream-server /usr/local/bin/slipstream-server
sudo systemctl restart slipstream-rust-server
```

## Troubleshooting

### Using the Built-in Tools

The management menu provides quick access to troubleshooting tools:

1. **Check service status** (menu option 3): Shows if services are running properly
2. **View service logs** (menu option 4): Real-time monitoring of service logs
3. **Show configuration info** (menu option 5): Display current configuration

### Common Issues

**Service Won't Start**:
```bash
slipstream-rust-deploy  # Use menu option 3 to check status
# Or manually:
sudo systemctl status slipstream-rust-server    # Check service status
sudo journalctl -u slipstream-rust-server -n 50 # Check logs for errors
ls -la /usr/local/bin/slipstream-server         # Verify binary exists and permissions
```

**Build Failures**:
```bash
# Check if all dependencies are installed
cargo --version          # Verify Rust is installed
cmake --version          # Verify cmake is installed
pkg-config --version    # Verify pkg-config is installed
pkg-config --exists openssl  # Verify OpenSSL headers are available

# Try rebuilding manually
cd /opt/slipstream-rust
cargo clean
cargo build --release -p slipstream-server
```

**DNS Configuration Issues**:
```bash
dig @YOUR_SERVER_IP s.mydomain.com           # Test DNS tunnel (from client)
sudo iptables -t nat -L PREROUTING -n -v     # Check iptables rules
```

**SOCKS Proxy Issues**:
```bash
curl --socks5 127.0.0.1:1080 http://httpbin.org/ip  # Test SOCKS proxy locally
sudo cat /etc/danted.conf                           # Check Dante configuration
```

**Port Check**:
```bash
sudo ss -tulnp | grep 5300  # Check slipstream-rust-server port
sudo ss -tulnp | grep 1080  # Check SOCKS proxy port (if enabled)
```

**Certificate Issues**:
```bash
# Verify certificates exist and have correct permissions
ls -la /etc/slipstream-rust/*.pem
# Regenerate if needed (will be done automatically on reconfiguration)
```

## Advanced Features

### Performance Monitoring

Use the built-in log viewer (menu option 4) or manual commands:

```bash
sudo ss -tulnp | grep -E "(5300|1080)"        # Monitor connection count
sudo systemctl status slipstream-rust-server  # Check service resources
sudo journalctl -u slipstream-rust-server -f --no-pager # Monitor logs for errors
```

### Custom Build Options

If you need to customize the build process, you can modify the build in `/opt/slipstream-rust`:

```bash
cd /opt/slipstream-rust
# Make your changes
cargo build --release -p slipstream-server
sudo cp target/release/slipstream-server /usr/local/bin/slipstream-server
sudo systemctl restart slipstream-rust-server
```

## Differences from C Implementation

This deployment script is for the **Rust implementation** of slipstream, which differs from the C implementation in several ways:

- **Build from source**: No pre-built binaries available; must build on the server
- **TLS certificates**: Uses TLS certificates (cert.pem/key.pem) instead of public/private keys
- **Build dependencies**: Requires Rust toolchain, cmake, pkg-config, and OpenSSL development headers
- **Longer setup time**: Initial build can take 10-30 minutes
- **Repository location**: Builds from `https://github.com/Mygod/slipstream-rust`

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## Acknowledgments

- [dnstt](https://dnstt.network) by David Fifield
- [slipstream](https://github.com/EndPositive/slipstream) by Jop Zitman (C implementation)
- [slipstream-rust](https://github.com/Mygod/slipstream-rust) by Mygod (Rust implementation)
- [dnstt-deploy](https://github.com/bugfloyd/dnstt-deploy) by Yashar Hosseinpour
- [slipstream-deploy](https://github.com/squirtea/slipstream-deploy) (C implementation deployment script)
- [Dante SOCKS server](https://www.inet.no/dante/) for SOCKS proxy functionality

---

**Made with ❤️ for privacy and security**
