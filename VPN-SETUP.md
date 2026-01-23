# WireGuard VPN Setup

Secure VPN server setup using WireGuard for Ubuntu EC2.

## 📋 What is WireGuard?

WireGuard is a modern, fast, and secure VPN protocol that's:
- ✅ Easy to configure
- ✅ Extremely fast
- ✅ Highly secure
- ✅ Cross-platform (iOS, Android, Windows, macOS, Linux)

## 🚀 Quick Setup

### Step 1: Install and Configure WireGuard Server

```bash
cd vpn
sudo ./setup-wireguard.sh
```

This script will:
- Install WireGuard
- Generate server keys
- Configure IP forwarding
- Set up firewall rules
- Start the VPN server

### Step 2: Configure EC2 Security Group

Add this rule to your EC2 security group:
```
Type: Custom UDP
Port: 51820
Source: 0.0.0.0/0 (or your specific IPs)
Description: WireGuard VPN
```

### Step 3: Add VPN Clients

```bash
sudo ./add-client.sh laptop
sudo ./add-client.sh phone
sudo ./add-client.sh tablet
```

Each client will get:
- A unique configuration file
- A QR code for mobile devices
- Connection instructions

## 📱 Client Setup

### Mobile (iOS/Android)

1. Install WireGuard app from App Store or Play Store
2. Scan the QR code displayed after running `add-client.sh`
3. Activate the VPN connection

### Desktop/Laptop (Windows/Mac/Linux)

1. **Download WireGuard:**
   - Windows: https://www.wireguard.com/install/
   - macOS: https://apps.apple.com/app/wireguard/id1451685025
   - Linux: `sudo apt install wireguard`

2. **Copy configuration file from server:**
```bash
scp -i your-key.pem ubuntu@your-server-ip:/etc/wireguard/clients/laptop.conf .
```

3. **Import and activate:**
   - Windows/Mac: Import the .conf file in WireGuard app
   - Linux: 
     ```bash
     sudo cp laptop.conf /etc/wireguard/
     sudo wg-quick up laptop
     ```

## 🗑️ Uninstall WireGuard

To completely remove WireGuard from your system:

```bash
cd vpn
sudo ./uninstall-wireguard.sh
```

This will:
- Stop and disable WireGuard service
- Remove WireGuard packages
- Clean up all configuration files
- Remove firewall rules
- Optionally backup configuration before removal
- Optionally disable IP forwarding

## 🔧 Management Commands

### List all clients
```bash
sudo ./list-clients.sh
```

Shows all configured clients and active connections.

### Remove a client
```bash
sudo ./remove-client.sh client-name
```

Removes client from VPN server.

### Check VPN status
```bash
sudo wg show
```

Shows server status and connected clients.

### View server logs
```bash
sudo journalctl -u wg-quick@wg0 -f
```

### Restart VPN server
```bash
sudo systemctl restart wg-quick@wg0
```

### Stop VPN server
```bash
sudo systemctl stop wg-quick@wg0
```

### Start VPN server
```bash
sudo systemctl start wg-quick@wg0
```

## 📂 File Locations

- Server config: `/etc/wireguard/wg0.conf`
- Client configs: `/etc/wireguard/clients/`
- Server keys: `/etc/wireguard/server_*.key`

## 🔐 Security Best Practices

1. ✅ Keep server keys secure (`/etc/wireguard/server_private.key`)
2. ✅ Limit security group to known IPs when possible
3. ✅ Use strong client names (avoid default names)
4. ✅ Remove unused clients regularly
5. ✅ Monitor active connections periodically
6. ✅ Keep WireGuard updated: `sudo apt update && sudo apt upgrade wireguard`

## 🌐 VPN Network Details

- **Server IP**: 10.8.0.1
- **VPN Subnet**: 10.8.0.0/24
- **Client IPs**: 10.8.0.2 - 10.8.0.254
- **Port**: 51820 (UDP)
- **DNS**: 1.1.1.1, 8.8.8.8

## 🐛 Troubleshooting

### Client can't connect

1. Check if VPN server is running:
```bash
sudo systemctl status wg-quick@wg0
```

2. Check firewall:
```bash
sudo ufw status
```

3. Verify security group allows UDP port 51820

4. Check server logs:
```bash
sudo journalctl -u wg-quick@wg0 -n 50
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

### Slow VPN connection

1. Check server load:
```bash
top
```

2. Test server bandwidth:
```bash
curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -
```

3. Consider upgrading EC2 instance type

### Client shows as disconnected

1. Check keepalive setting in client config (should be 25)
2. Verify client public key in server config
3. Restart both client and server

## 🔄 Backup and Restore

### Backup VPN configuration
```bash
sudo tar -czf wireguard-backup.tar.gz /etc/wireguard/
```

### Restore VPN configuration
```bash
sudo tar -xzf wireguard-backup.tar.gz -C /
sudo systemctl restart wg-quick@wg0
```

## 📊 Monitoring

### View active connections
```bash
sudo wg show wg0
```

### Monitor bandwidth usage
```bash
sudo wg show wg0 transfer
```

### Check connection quality
```bash
sudo wg show wg0 latest-handshakes
```

## 🆘 Support

For issues or questions:
- WireGuard Documentation: https://www.wireguard.com/
- Ubuntu WireGuard Guide: https://ubuntu.com/server/docs/wireguard-vpn

## 📄 License

MIT License - Free to use and modify.
