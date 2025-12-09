# SSL Certificate Management Scripts

Scripts for managing SSL certificates using Let's Encrypt and Certbot on Ubuntu.

## 📁 Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `setup-certbot.sh` | Install Certbot and configure auto-renewal | `sudo ./setup-certbot.sh` |
| `obtain-ssl.sh` | Interactive guide to choose the right script | `sudo ./obtain-ssl.sh` |
| `obtain-ssl-static.sh` | SSL for static sites (React, HTML) | `sudo ./obtain-ssl-static.sh <domain> <web_root> [email]` |
| `obtain-ssl-proxy.sh` | SSL for app servers (Node.js, Next.js) | `sudo ./obtain-ssl-proxy.sh <domain> <port> [email]` |
| `renew-ssl.sh` | Manually renew certificates | `sudo ./renew-ssl.sh [--force]` |
| `list-ssl.sh` | List all certificates and status | `sudo ./list-ssl.sh` |
| `revoke-ssl.sh` | Revoke and delete a certificate | `sudo ./revoke-ssl.sh <domain>` |

## 🚀 Quick Start

### Step 1: Install Certbot

```bash
sudo ./setup-certbot.sh
```

### Step 2: Choose Your Application Type

#### Option A: Static Site (React, HTML, Vue)
For sites where Nginx serves files directly from a directory:

```bash
# React app (after npm run build)
sudo ./obtain-ssl-static.sh myapp.com /var/www/myapp admin@example.com

# HTML website
sudo ./obtain-ssl-static.sh example.com /var/www/example admin@example.com

# With www subdomain
sudo ./obtain-ssl-static.sh "example.com,www.example.com" /var/www/example admin@example.com
```

#### Option B: App Server (Node.js, Next.js, Express)
For apps running on a port that need Nginx as reverse proxy:

```bash
# Next.js app on port 3000
sudo ./obtain-ssl-proxy.sh myapp.com 3000 admin@example.com

# Node.js API on port 4000
sudo ./obtain-ssl-proxy.sh api.example.com 4000 admin@example.com

# Express app on port 5000
sudo ./obtain-ssl-proxy.sh backend.example.com 5000 admin@example.com
```

#### Interactive Mode
Not sure which to use? Run the interactive script:

```bash
sudo ./obtain-ssl.sh
```

### Step 3: Verify

```bash
sudo ./list-ssl.sh
```

## 📋 Application Types Explained

### Static Sites (`obtain-ssl-static.sh`)

Use this for:
- **React** apps (after `npm run build`)
- **Vue** apps (after `npm run build`)
- **Angular** apps (after `ng build`)
- **Plain HTML** websites
- Any site that consists of static files (HTML, CSS, JS, images)

What it does:
- Creates Nginx config to serve files from `<web_root>`
- Supports React Router / SPA routing (serves index.html for all routes)
- Enables gzip compression and caching
- Obtains SSL certificate from Let's Encrypt

### App Servers (`obtain-ssl-proxy.sh`)

Use this for:
- **Next.js** apps (running `npm start`)
- **Node.js / Express** servers
- **Nest.js** apps
- **Fastify** servers
- Any app running on a local port

What it does:
- Creates Nginx reverse proxy to `localhost:<port>`
- Enables WebSocket support (`/ws`, `/socket.io`)
- Enables gzip compression
- Handles large request bodies (50MB)
- Obtains SSL certificate from Let's Encrypt

## 🔄 Auto-Renewal

Certbot automatically configures a systemd timer for renewal:

- **Runs**: Twice daily
- **Renews**: Certificates expiring within 30 days
- **Nginx Reload**: Automatic via deploy hook

Check renewal status:
```bash
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

## 🧪 Testing with Staging

Let's Encrypt has rate limits. Use staging for testing:

```bash
# Test with staging certificate (not trusted by browsers)
sudo ./obtain-ssl-proxy.sh example.com 3000 admin@example.com --staging

# Once working, get production certificate
sudo ./revoke-ssl.sh example.com
sudo ./obtain-ssl-proxy.sh example.com 3000 admin@example.com
```

### Rate Limits (Production)

- **50 certificates** per registered domain per week
- **5 duplicate certificates** per week
- **5 failed validations** per hour per account

## 🔒 Certificate Locations

After obtaining a certificate:

```
/etc/letsencrypt/live/yourdomain.com/
├── cert.pem       # Domain certificate
├── chain.pem      # Intermediate certificate
├── fullchain.pem  # cert.pem + chain.pem (use this)
└── privkey.pem    # Private key
```

Nginx config location:
```
/etc/nginx/sites-available/<domain-name>
```

## 📝 What Certbot Does Automatically

When you run these scripts, Certbot automatically:

1. ✅ Validates domain ownership via HTTP challenge
2. ✅ Obtains SSL certificate from Let's Encrypt
3. ✅ Updates Nginx config with SSL settings
4. ✅ Adds HTTP → HTTPS redirect
5. ✅ Configures certificate auto-renewal

You don't need to manually edit Nginx SSL settings!

## 🔧 Troubleshooting

### "Challenge failed" error

1. Verify DNS points to your server:
   ```bash
   dig +short yourdomain.com
   ```

2. Check port 80 is accessible:
   ```bash
   sudo ufw allow 80
   curl -I http://yourdomain.com
   ```

3. Ensure Nginx is running:
   ```bash
   sudo systemctl status nginx
   ```

### Certificate not renewing

1. Test renewal:
   ```bash
   sudo certbot renew --dry-run
   ```

2. Check timer:
   ```bash
   sudo systemctl status certbot.timer
   ```

3. View logs:
   ```bash
   sudo journalctl -u certbot
   ```

### App not accessible after SSL

1. Check your app is running:
   ```bash
   curl http://localhost:3000  # or your port
   ```

2. Check Nginx config:
   ```bash
   sudo nginx -t
   cat /etc/nginx/sites-available/<your-domain>
   ```

3. Check Nginx logs:
   ```bash
   sudo tail -f /var/log/nginx/error.log
   ```

## 📚 Useful Commands

```bash
# List all certificates
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# View Nginx config
cat /etc/nginx/sites-available/<domain-name>

# Test Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# View certificate details
sudo openssl x509 -in /etc/letsencrypt/live/example.com/cert.pem -text -noout
```

## 🔗 Resources

- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Certbot Documentation](https://certbot.eff.org/docs/)
- [SSL Labs Test](https://www.ssllabs.com/ssltest/) - Test your SSL configuration
