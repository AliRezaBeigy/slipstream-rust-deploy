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

## Quick Start

### Prerequisites
- Linux server (Fedora, Rocky, CentOS, Debian, or Ubuntu)
- Root access or sudo privileges
- Internet connection for downloading binaries or building from source
- **Domain name with proper DNS configuration** (see DNS Domain Setup section above)
- **Build dependencies (only if building from source)**: The script will automatically install Rust toolchain, cmake, pkg-config, and OpenSSL development headers when prebuilt binaries are not available

### Installation

**One-command installation:**
```bash
bash <(curl -Ls https://raw.githubusercontent.com/AliRezaBeigy/slipstream-rust-deploy/master/slipstream-rust-deploy.sh)
```

This command will:
1. Download and install the script to `/usr/local/bin/slipstream-rust-deploy`
2. Download prebuilt binary (if available for your architecture) OR install build dependencies and compile from source
3. Start the interactive setup process
4. Configure your slipstream-rust server automatically

**Note**: For supported platforms (Linux x86_64, macOS ARM64, macOS Intel), prebuilt binaries are used for faster installation. For other architectures, the script will build from source which may take 10-30 minutes.

## Client Usage

After setting up the server, you can connect to it using the slipstream-rust client.

### Download Client Binaries

Prebuilt client binaries are available for the following platforms:

| Platform | Download |
|----------|----------|
| Linux (x86_64) | [slipstream-client-linux-amd64](https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-linux-amd64) |
| Windows (x86_64) | [slipstream-client-windows-amd64.exe](https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-windows-amd64.exe) |
| macOS (ARM64) | [slipstream-client-darwin-arm64](https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-darwin-arm64) |
| macOS (Intel) | [slipstream-client-darwin-amd64](https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-darwin-amd64) |

### Quick Start (Linux/macOS)

```bash
# Download the client for your platform
curl -Lo slipstream-client https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-linux-amd64
chmod +x slipstream-client

# Run the client (connects to your server via DNS tunnel)
./slipstream-client --resolver YOUR_SERVER_IP:53 --domain s.example.com
```

### Quick Start (Windows)

```powershell
# Download the client
Invoke-WebRequest -Uri "https://github.com/AliRezaBeigy/slipstream-rust-deploy/releases/latest/download/slipstream-client-windows-amd64.exe" -OutFile "slipstream-client.exe"

# Run the client
.\slipstream-client.exe --resolver YOUR_SERVER_IP:53 --domain s.example.com
```

**Windows Tip**: slipstream-rust relies on the Microsoft Visual C++ operating environment. If an error prompts "Cannot find MSVC*.dll" when the program starts, please click the link below to download and install the Microsoft Visual C++ operating environment.

[Download the latest supported version of Visual C++ Redistributable Package | Microsoft Docs](https://docs.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist?view=msvc-170)

### Client Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `--resolver`, `-r` | DNS resolver address (your server) | Required | `--resolver 203.0.113.2:53` |
| `--authoritative` | Use authoritative mode for resolver | - | `--authoritative 203.0.113.2:53` |
| `--domain`, `-d` | Tunnel domain (configured on server) | Required | `--domain s.example.com` |
| `--tcp-listen-port`, `-l` | Local TCP port to listen on | 5201 | `-l 5201` |
| `--cert` | Path to server certificate for pinning | - | `--cert server.pem` |
| `--congestion-control`, `-c` | Congestion control algorithm | - | `-c bbr` or `-c dcubic` |
| `--keep-alive-interval`, `-t` | Keep-alive interval in ms | 400 | `-t 500` |
| `--gso` | Enable UDP GSO (Generic Segmentation Offload) | Disabled | `--gso` |

**Note on GSO**: GSO (Generic Segmentation Offload) is a Linux kernel feature that improves UDP performance by batching multiple packets together and letting the NIC hardware handle segmentation. This reduces CPU overhead for high-throughput transfers. Currently, the `--gso` flag is recognized but not yet fully implemented in the Rust client loop (a warning will be printed).

### Using the Tunnel

The client listens on TCP port **5201** by default. Once connected, you can tunnel traffic through it.

**SSH Mode**: If your server is configured in SSH mode, connect directly via the tunnel:
```bash
# Connect to SSH through the DNS tunnel
ssh -o ProxyCommand="nc 127.0.0.1 5201" user@localhost
```

**SOCKS Mode**: If your server is configured with SOCKS mode, the tunnel connects to the Dante SOCKS proxy on the server. You can use tools like `proxychains` or configure applications to use the tunnel.

**Shadowsocks Mode**: If your server is configured with the new Shadowsocks option, slipstream tunnels traffic to a Shadowsocks server running locally on the server (listening on `127.0.0.1` by default). Typical usage is to run `ss-local` on the client and forward its outbound encrypted connection through the slipstream client.

Example `ss-local` JSON config (client):

```json
{
	"server": "127.0.0.1",
	"server_port": 8388,
	"local_address": "127.0.0.1",
	"local_port": 10800,
	"password": "your_password",
	"method": "aes-256-gcm"
}
```


Run `ss-local` and instruct it to go through slipstream's SOCKS proxy produced by `slipstream-client`:

```bash
# Start slipstream client (creates local SOCKS proxy on 127.0.0.1:1080)
./slipstream-client --resolver YOUR_SERVER_IP:53 --domain s.example.com --listen 127.0.0.1:1080

# Run ss-local, forwarding outbound connection through slipstream's SOCKS proxy
ss-local -c config.json --socks5-proxy 127.0.0.1:1080

# Point your applications at ss-local's local port (127.0.0.1:10800)
```

### Quick Start (Android)

You can use the [slipstream-plugin-android](https://github.com/Mygod/slipstream-plugin-android) with the [Shadowsocks Android app](https://github.com/shadowsocks/shadowsocks-android) to connect from your Android device.

**Instructions:**

1. Install the Shadowsocks app from the Play Store or [GitHub releases](https://github.com/shadowsocks/shadowsocks-android/releases).
2. Install the slipstream plugin from [Mygod's slipstream-plugin-android releases](https://github.com/Mygod/slipstream-plugin-android/releases).
3. In the Shadowsocks app, add a new profile for your server:
     - **Server**: `test.example.com` -> your A record domain
    - **Port**: `53` -> Important: Use port 53 for DNS tunneling
    - **Password**: Your Shadowsocks password
4. In the profile's "Plugin" settings, select `slipstream` as the plugin.
5. Configure the plugin options as follows:
	 - **Plugin options:**
		 - Domain: `s.example.com` -> your NS record domain
         - Authoritative mode: off
         - Pinned certificate: leave blank
         - Keep-alive interval: leave blank  
    DNS Resolver is not managed by the plugin; it uses the Shadowsocks app's DNS settings.
6. Save and connect. The Shadowsocks app will tunnel traffic through the slipstream DNS tunnel using the plugin.

For more details and troubleshooting, see the [slipstream-plugin-android documentation](https://github.com/Mygod/slipstream-plugin-android).

Notes:
- The server-side Shadowsocks instance is intentionally bound to `127.0.0.1` and the slipstream server forwards DNS-tunneled traffic to that local address. Do not point `ss-server` at the public interface.
- The deploy script writes the server config to `/etc/shadowsocks-libev/config.json` and manages the `shadowsocks-libev-server@config` (or `shadowsocks-libev`) systemd service when available.

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

**Shadowsocks Mode (Option 3)**
- Sets up a local `shadowsocks-libev` server bound to `127.0.0.1` (default port 8388)
- Slipstream tunnels DNS traffic to the Shadowsocks server so clients can run `ss-local` locally and send encrypted traffic through the tunnel
- Server config path: `/etc/shadowsocks-libev/config.json` (script sets `"mode": "tcp_only"` to avoid UDP handshake issues)

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
/usr/local/bin/slipstream-server               # Main binary (prebuilt or built from source)
/opt/slipstream-rust/                          # Source code and build directory (only when building from source)
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

**Uninstall**:
```bash
bash <(curl -Ls https://raw.githubusercontent.com/AliRezaBeigy/slipstream-rust-deploy/master/slipstream-rust-deploy.sh) uninstall           # Complete removal of slipstream-rust
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

### Updating the Binary

To update to the latest version:

```bash
slipstream-rust-deploy
# Choose option 1: Install/Reconfigure slipstream-rust server
# The script will automatically download the latest prebuilt binary or rebuild from source
```

### Building from Source (Manual)

If you need to build slipstream-rust from source manually:

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

**Shadowsocks / No logs / UDP errors**:

- If `ss-server` shows "suspicious UDP packet" errors or you see no Shadowsocks logs, ensure the client traffic is properly routed through the slipstream tunnel (see the Shadowsocks Mode example above). The deploy script configures Shadowsocks to use TCP-only mode by default (`"mode": "tcp_only"`) because the DNS tunnel in this setup carries TCP traffic to the server-side `ss-server`.
- Confirm `ss-server` is running and listening on `127.0.0.1:<port>` on the server:

```bash
ss -tlnp | grep ss-server
journalctl -u shadowsocks-libev-server@config -f
```

If `ss-local` traffic isn't reaching `ss-server`, verify that `slipstream-server` is receiving and forwarding connections:

```bash
journalctl -u slipstream-rust-server -f
systemctl status slipstream-rust-server
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

## Features

- **Multi-distribution support**: Fedora, Rocky Linux, CentOS, Debian, Ubuntu
- **Prebuilt binaries**: Automatically downloads prebuilt binaries for supported platforms (Linux x86_64, macOS ARM64, macOS Intel)
- **Fallback to source build**: Automatically builds from source when prebuilt binaries aren't available
- **Interactive management menu**: Easy-to-use interface for all operations
- **Self-updating capability**: Built-in update mechanism for the script
- **Automatic detection**: OS and SSH port detection
- **Systemd service integration**: Creates and manages a dedicated systemd service for reliable operation, automatic startup on boot, and comprehensive logging
- **Security hardened**: Non-root service execution with systemd security features
- **Smart configuration**: Persistent settings and automatic certificate reuse
- **Flexible tunneling**: SSH mode or SOCKS proxy mode
- **Network ready**: Automatic firewall and iptables configuration
- **TLS certificates**: Automatic generation and management of TLS certificates


## Differences from C Implementation

This deployment script is for the **Rust implementation** of slipstream, which differs from the C implementation in several ways:

- **Prebuilt binaries**: Prebuilt binaries are available for common platforms (Linux x86_64, Windows x86_64, macOS ARM64, macOS Intel)
- **TLS certificates**: Uses TLS certificates (cert.pem/key.pem) instead of public/private keys
- **Build dependencies**: When building from source, requires Rust toolchain, cmake, pkg-config, and OpenSSL development headers
- **Repository location**: Uses binaries from or builds from `https://github.com/Mygod/slipstream-rust`

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
