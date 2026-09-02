# OpenVPN Server Setup

Enterprise-grade VPN server setup using OpenVPN for Ubuntu EC2.

## 📋 What is OpenVPN?

OpenVPN is the industry-standard, open-source VPN solution that's:
- ✅ Battle-tested (20+ years in production)
- ✅ Highly configurable
- ✅ Widely supported across all platforms
- ✅ Enterprise-ready with advanced features
- ✅ Excellent firewall traversal

## 🚀 Quick Setup

### Step 1: Install and Configure OpenVPN Server

```bash
cd vpn-openvpn
sudo ./setup-openvpn.sh
```

This script will:
- Install OpenVPN and Easy-RSA
- Set up Certificate Authority (CA)
- Generate server certificates and keys
- Configure OpenVPN server
- Set up firewall rules and IP forwarding
- Start the VPN server

### Step 2: Configure EC2 Security Group

Add this rule to your EC2 security group:
```
Type: Custom UDP
Port: 1194
Source: 0.0.0.0/0 (or your specific IPs)
Description: OpenVPN Server
```

**Alternative TCP Configuration:**
If you need better firewall traversal, you can configure OpenVPN to use TCP by editing `/etc/openvpn/server/server.conf` and changing `proto udp` to `proto tcp`.

### Step 3: Add VPN Clients

```bash
sudo ./add-client.sh laptop
sudo ./add-client.sh phone
sudo ./add-client.sh tablet
```

Each client will get:
- A unique certificate and key
- A single .ovpn configuration file (all-in-one)
- Connection instructions

## 📱 Client Setup

### Windows

1. **Download OpenVPN GUI:**
   - Visit: https://openvpn.net/community-downloads/
   - Download and install OpenVPN GUI

2. **Import configuration:**
   - Copy the .ovpn file to your computer
   - Right-click OpenVPN GUI icon in system tray
   - Select "Import file" and choose your .ovpn file

3. **Connect:**
   - Right-click OpenVPN GUI icon
   - Select your connection
   - Click "Connect"

### macOS

1. **Download Tunnelblick:**
   - Visit: https://tunnelblick.net/
   - Download and install Tunnelblick

2. **Import configuration:**
   - Double-click the .ovpn file
   - Tunnelblick will import it automatically

3. **Connect:**
   - Click Tunnelblick icon in menu bar
   - Select your connection
   - Click "Connect"

### Linux

1. **Install OpenVPN:**
```bash
sudo apt update
sudo apt install openvpn
```

2. **Copy configuration file from server:**
```bash
scp -i your-key.pem ubuntu@your-server-ip:/etc/openvpn/clients/laptop.ovpn ~/
```

3. **Connect:**
```bash
sudo openvpn --config ~/laptop.ovpn
```

**Or run as service:**
```bash
sudo cp laptop.ovpn /etc/openvpn/client/laptop.conf
sudo systemctl enable openvpn-client@laptop
sudo systemctl start openvpn-client@laptop
```

### iOS

1. **Install OpenVPN Connect:**
   - Open App Store
   - Search for "OpenVPN Connect"
   - Install the app

2. **Transfer .ovpn file:**
   - Email the file to yourself
   - Use AirDrop
   - Or use iTunes File Sharing

3. **Import and connect:**
   - Open the .ovpn file on your device
   - Tap "Add" to import into OpenVPN Connect
   - Tap the toggle to connect

### Android

1. **Install OpenVPN for Android:**
   - Open Google Play Store
   - Search for "OpenVPN for Android"
   - Install the app

2. **Import configuration:**
   - Transfer .ovpn file to your device
   - Open OpenVPN for Android
   - Tap "+" icon
   - Select "Import" and choose your .ovpn file

3. **Connect:**
   - Tap the connection name
   - Tap "Connect"

## 🗑️ Uninstall OpenVPN

To completely remove OpenVPN from your system:

```bash
cd vpn-openvpn
sudo ./uninstall-openvpn.sh
```

This will:
- Stop and disable OpenVPN service
- Remove OpenVPN and Easy-RSA packages
- Clean up all configuration files and certificates
- Remove Certificate Authority (CA)
- Remove firewall rules
- Optionally backup configuration before removal
- Optionally disable IP forwarding

**Important:** Make sure to backup your CA if you may need to restore OpenVPN later!

## 🔧 Management Commands

### List all clients
```bash
cd vpn-openvpn
sudo ./list-clients.sh
```

Shows all configured clients and active connections.

### Remove a client
```bash
sudo ./remove-client.sh client-name
```

Revokes client certificate and removes configuration.

### Check VPN status
```bash
sudo systemctl status openvpn-server@server
```

Shows OpenVPN server status.

### View active connections
```bash
cat /etc/openvpn/server/openvpn-status.log
```

Shows currently connected clients and routing information.

### View server logs
```bash
sudo journalctl -u openvpn-server@server -f
```

Live view of server logs.

### Restart VPN server
```bash
sudo systemctl restart openvpn-server@server
```

### Stop VPN server
```bash
sudo systemctl stop openvpn-server@server
```

### Start VPN server
```bash
sudo systemctl start openvpn-server@server
```

## 📂 File Locations

- Server config: `/etc/openvpn/server/server.conf`
- Client configs: `/etc/openvpn/clients/`
- Certificate Authority: `/etc/openvpn/easy-rsa/pki/`
- Server certificates: `/etc/openvpn/server/`
- Status log: `/etc/openvpn/server/openvpn-status.log`
- Server log: `/etc/openvpn/server/openvpn.log`

## 🔐 Security Best Practices

1. ✅ Keep server private key secure (`/etc/openvpn/server/server.key`)
2. ✅ Protect Certificate Authority (`/etc/openvpn/easy-rsa/pki/`)
3. ✅ Use strong, unique client names
4. ✅ Revoke unused client certificates (don't just delete)
5. ✅ Regularly review connected clients
6. ✅ Keep OpenVPN updated: `sudo apt update && sudo apt upgrade openvpn`
7. ✅ Back up your CA regularly
8. ✅ Use Certificate Revocation List (CRL) - automatically enabled
9. ✅ Compression is disabled - see below

## 🚫 Compression is disabled

Compressing data before encrypting it makes the tunnel vulnerable to the
[VORACLE attack](https://community.openvpn.net/openvpn/wiki/VORACLE), which lets
an attacker recover plaintext such as session cookies. OpenVPN has deprecated
all compression options for this reason, and OpenVPN 2.6 disables compression by
default.

These scripts therefore ship compression off:

- `setup-openvpn.sh` writes `allow-compression no` into `server.conf` (on
  OpenVPN 2.5+, where the option exists) and never sets `comp-lzo` or `compress`
- `add-client.sh` generates `.ovpn` files with no compression directive

Verify it on a running server:
```bash
grep -E 'allow-compression|comp-lzo|compress' /etc/openvpn/server/server.conf
```
You should see only `allow-compression no`.

**Do not re-enable it.** Adding `comp-lzo` or `compress` to a client config
while the server sets `allow-compression no` also makes that client fail to
connect, since OpenVPN 2.6 clients refuse contradictory compression settings.

### Existing clients need no changes

If you previously set this server up with compression, you do **not** have to
reissue or re-download any `.ovpn` file. A client config that still contains
`comp-lzo` keeps working:

- In current OpenVPN releases `comp-lzo` is only an alias for `asym`, so the
  client never compresses what it sends
- The server sends nothing compressed because of `allow-compression no`
- `allow-compression no` still accepts the compression framing byte that such a
  client adds, so there is no framing mismatch

The traffic is therefore uncompressed in both directions and VORACLE is
mitigated even for clients using an old config. You can still drop `comp-lzo`
from client configs when convenient, since the option is deprecated.

## 🌐 VPN Network Details

- **Server IP**: 10.8.0.0
- **VPN Subnet**: 10.8.0.0/24
- **Client IPs**: 10.8.0.2 - 10.8.0.254
- **Port**: 1194 (UDP)
- **Protocol**: UDP (can be changed to TCP)
- **Encryption**: AES-256-GCM
- **Authentication**: SHA256
- **DNS**: 1.1.1.1, 8.8.8.8
- **Compression**: disabled (VORACLE)

## 🐛 Troubleshooting

### Client can't connect

1. Check if OpenVPN server is running:
```bash
sudo systemctl status openvpn-server@server
```

2. Check firewall:
```bash
sudo ufw status
```

3. Verify security group allows port 1194/UDP

4. Check server logs:
```bash
sudo journalctl -u openvpn-server@server -n 50
```

5. Verify client certificate hasn't been revoked:
```bash
cat /etc/openvpn/server/crl.pem
```

### No internet access through VPN

1. Check IP forwarding:
```bash
sysctl net.ipv4.ip_forward
# Should output: net.ipv4.ip_forward = 1
```

2. Verify iptables rules:
```bash
sudo iptables -t nat -L POSTROUTING -v -n
```

3. Check OpenVPN server config for push routes:
```bash
grep "push" /etc/openvpn/server/server.conf
```

### Connection drops frequently

1. If behind NAT/firewall, enable keepalive in client config:
```
keepalive 10 60
```

2. Try TCP instead of UDP (edit server.conf):
```
proto tcp
```

3. Check server resources:
```bash
top
htop
```

### Certificate errors

1. Verify certificates are valid:
```bash
cd /etc/openvpn/easy-rsa
./easyrsa show-cert client-name
```

2. Check certificate expiration:
```bash
openssl x509 -in /etc/openvpn/clients/client-name.ovpn -text -noout | grep "Not After"
```

### Slow VPN connection

1. Check server bandwidth:
```bash
sudo apt install speedtest-cli
speedtest-cli
```

2. Consider upgrading EC2 instance type

3. Use UDP instead of TCP for better performance

Note: compression is disabled by design and is not a tuning option. See
[Compression is disabled](#-compression-is-disabled).

## 🔄 Backup and Restore

### Backup VPN configuration and CA

**Important: Backup your Certificate Authority regularly!**

```bash
# Backup everything
sudo tar -czf openvpn-backup-$(date +%Y%m%d).tar.gz /etc/openvpn/

# Backup only CA and keys (most critical)
sudo tar -czf openvpn-ca-backup-$(date +%Y%m%d).tar.gz /etc/openvpn/easy-rsa/pki/ /etc/openvpn/server/

# Download backup to local machine
scp -i your-key.pem ubuntu@your-server-ip:~/openvpn-backup-*.tar.gz .
```

### Restore VPN configuration

```bash
# Restore from backup
sudo tar -xzf openvpn-backup.tar.gz -C /

# Restart OpenVPN
sudo systemctl restart openvpn-server@server
```

## 📊 Monitoring

### View active connections with details
```bash
cat /etc/openvpn/server/openvpn-status.log
```

### Monitor bandwidth usage
```bash
sudo apt install vnstat
sudo vnstat -i tun0
```

### Check connected clients in real-time
```bash
watch -n 5 'cat /etc/openvpn/server/openvpn-status.log | grep -A 10 "CLIENT LIST"'
```

### Monitor logs continuously
```bash
sudo tail -f /etc/openvpn/server/openvpn.log
```

## ⚙️ Advanced Configuration

### Enable Two-Factor Authentication (2FA)

1. Install Google Authenticator:
```bash
sudo apt install libpam-google-authenticator
```

2. Add to OpenVPN config:
```
plugin /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so openvpn
```

### Use TCP instead of UDP

Edit `/etc/openvpn/server/server.conf`:
```
proto tcp
```

Then restart: `sudo systemctl restart openvpn-server@server`

### Custom DNS servers

Edit server config to push different DNS:
```
push "dhcp-option DNS 9.9.9.9"
push "dhcp-option DNS 149.112.112.112"
```

### Split tunneling (Route only specific traffic)

Remove the redirect-gateway line from server.conf and add specific routes:
```
# Comment out:
# push "redirect-gateway def1 bypass-dhcp"

# Add specific routes:
push "route 192.168.1.0 255.255.255.0"
push "route 10.0.0.0 255.255.255.0"
```

## 🔄 Certificate Management

### Check certificate expiration

```bash
cd /etc/openvpn/easy-rsa
./easyrsa show-cert server
./easyrsa show-cert client-name
```

### Renew server certificate (before expiration)

```bash
cd /etc/openvpn/easy-rsa
./easyrsa renew server
sudo systemctl restart openvpn-server@server
```

### View all issued certificates

```bash
cd /etc/openvpn/easy-rsa
./easyrsa show-ca
ls pki/issued/
```

## 🆘 Support

For issues or questions:
- OpenVPN Documentation: https://openvpn.net/community-resources/
- Ubuntu OpenVPN Guide: https://ubuntu.com/server/docs/service-openvpn
- Community Forums: https://forums.openvpn.net/

## 📄 License

MIT License - Free to use and modify.
