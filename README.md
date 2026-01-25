# CI/CD Setup Scripts for Ubuntu EC2 with GitHub Actions

Complete setup scripts for deploying Node.js/Next.js/React applications on Ubuntu EC2 with GitHub Actions self-hosted runner, PM2, and Nginx.

## 📁 Project Structure

```
cicd-setup/
├── setup-dependencies.sh      # Install Node.js, PM2, Nginx
├── setup-runner.sh            # Setup GitHub Actions runner
├── nginx/
│   ├── proxy.conf.example     # Nginx for Node.js/TypeScript/Next.js
│   ├── static.conf.example    # Nginx for HTML/React/Vue/Angular
│   └── README.md              # Nginx documentation
├── ssl/
│   ├── setup-certbot.sh       # Install Certbot
│   ├── obtain-ssl-proxy.sh    # SSL for reverse proxy
│   ├── obtain-ssl-static.sh   # SSL for static sites
│   ├── renew-ssl.sh           # Renew certificates
│   └── list-ssl.sh            # List certificates
├── vpn/
│   ├── setup-wireguard.sh     # Setup WireGuard VPN server
│   ├── add-client.sh          # Add VPN client
│   ├── list-clients.sh        # List all clients
│   ├── remove-client.sh       # Remove VPN client
│   └── uninstall-wireguard.sh # Uninstall WireGuard completely
├── vpn-openvpn/
│   ├── setup-openvpn.sh       # Setup OpenVPN server
│   ├── add-client.sh          # Add OpenVPN client
│   ├── list-clients.sh        # List all clients
│   ├── remove-client.sh       # Remove client and revoke certificate
│   └── uninstall-openvpn.sh   # Uninstall OpenVPN completely
├── workflows/
│   ├── deploy-nodejs.yml      # Workflow for Node.js
│   ├── deploy-nodejs-ts.yml   # Workflow for TypeScript
│   ├── deploy-nextjs.yml      # Workflow for Next.js
│   ├── deploy-react.yml       # Workflow for React
│   └── deploy-static-html.yml # Workflow for static sites
├── VPN-SETUP.md               # WireGuard VPN setup guide
├── OPENVPN-SETUP.md           # OpenVPN setup guide
└── README.md                  # This file
```

## 🚀 Quick Start Guide

### Step 1: Launch EC2 Instance

1. Launch Ubuntu 22.04 LTS EC2 instance
2. Configure security groups:
   - SSH (22) - Your IP
   - HTTP (80) - 0.0.0.0/0
   - HTTPS (443) - 0.0.0.0/0

3. SSH into instance:
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### Step 2: Upload/Clone Scripts

```bash
# Clone repository on EC2
git clone https://github.com/your-username/cicd-setup.git
cd cicd-setup
chmod +x *.sh
```

### Step 3: Install Dependencies

```bash
# Install Node.js, PM2, Nginx, and build tools
sudo ./setup-dependencies.sh

# Or specify Node.js version
sudo ./setup-dependencies.sh 20
```

### Step 4: Setup GitHub Actions Runner

Get runner token from GitHub:
- Go to **Repository → Settings → Actions → Runners**
- Click **New self-hosted runner**
- Copy the token

Setup runner:
```bash
# Basic setup
./setup-runner.sh https://github.com/username/repo YOUR_TOKEN

# With custom name
./setup-runner.sh https://github.com/username/repo YOUR_TOKEN my-runner

# With custom name and labels
./setup-runner.sh https://github.com/username/repo YOUR_TOKEN my-runner "self-hosted,ubuntu,production"
```

**Parameters:**
- **repo_url**: GitHub repository URL (required)
- **token**: Runner registration token from GitHub (required)
- **runner_name**: Custom name for the runner (optional, default: hostname)
- **labels**: Comma-separated labels (optional, default: "self-hosted,ubuntu,ec2")

### Step 5: Configure GitHub Workflow

**1. Copy workflow to your repository:**

```bash
mkdir -p .github/workflows
cp /path/to/cicd-setup/workflows/deploy-nodejs.yml .github/workflows/deploy.yml
```

**2. Customize workflow file (`.github/workflows/deploy.yml`):**

Check and update these settings:
- **Trigger branch**: Change `main` to your branch name
- **Node version**: Update if needed (e.g., `18`, `20`, `22`)
- **Project name**: Optionally set custom name
- **Build command**: Ensure `npm run build` exists in package.json (for TS/Next.js)

**3. Add GitHub secret:**

Repository → Settings → Secrets → New secret:
- Name: `ENV_FILE`
- Value: Your entire `.env` file contents

**4. Create `ecosystem.config.js` on server (Node.js/Next.js only):**

SSH to server and create in `/home/ubuntu/app-deploy/your-repo-name/`:

```javascript
module.exports = {
  apps: [{
    name: 'my-app',
    script: './index.js',        // or './dist/index.js' for TypeScript
    instances: 'max',
    exec_mode: 'cluster',
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

**5. Add to `.gitignore`:**

```
ecosystem.config.js
.env
.env.local
```

**Before deploying, verify:**
- [ ] Workflow branch matches your repo
- [ ] Port is same in: app code, ecosystem.config.js, nginx config
- [ ] GitHub secret added (ENV_FILE)
- [ ] ecosystem.config.js created on server

### Step 6: Setup Nginx

#### For Node.js/TypeScript/Next.js (Port 3000 apps)

```bash
sudo cp nginx/proxy.conf.example /etc/nginx/sites-available/myapp
sudo nano /etc/nginx/sites-available/myapp
# Edit: server_name and port (default 3000)

sudo ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

#### For Static Sites (HTML/React/Vue)

```bash
sudo cp nginx/static.conf.example /etc/nginx/sites-available/mysite
sudo nano /etc/nginx/sites-available/mysite
# Edit: server_name and root path

sudo ln -s /etc/nginx/sites-available/mysite /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### Step 7: Configure DNS

Get your server IP:
```bash
curl ifconfig.me
```

Add DNS A record at your domain registrar:
```
Type: A
Name: @ (or subdomain)
Value: Your EC2 IP
TTL: 3600
```

Wait 15-30 minutes for DNS propagation, then test:
```bash
dig your-domain.com
curl http://your-domain.com
```

### Step 8: Setup SSL/HTTPS (Let's Encrypt)

After DNS is working, secure your site with free SSL certificate:

```bash
cd ssl

# 1. Install Certbot (one-time)
sudo ./setup-certbot.sh

# 2. Obtain SSL certificate
# For Node.js/TypeScript/Next.js (reverse proxy):
sudo ./obtain-ssl-proxy.sh your-domain.com 3000 your-email@example.com

# Examples:
sudo ./obtain-ssl-proxy.sh api.example.com 3000 admin@example.com

# For static sites (HTML/React/Vue):
sudo ./obtain-ssl-static.sh your-domain.com /var/www/your-site your-email@example.com

# Examples:
sudo ./obtain-ssl-static.sh example.com /var/www/example admin@example.com
sudo ./obtain-ssl-static.sh "example.com,www.example.com" /var/www/example admin@example.com
```

**Command parameters:**
- `obtain-ssl-proxy.sh <domain> <port> <email>`
  - **domain**: Your domain (single: `example.com` or multiple: `"example.com,www.example.com"`)
  - **port**: Your application port (e.g., 3000)
  - **email**: Your email for Let's Encrypt notifications

- `obtain-ssl-static.sh <domain> <web_root> <email>`
  - **domain**: Your domain (single: `example.com` or multiple: `"example.com,www.example.com"`)
  - **web_root**: Path where static files are located (e.g., /var/www/example)
  - **email**: Your email for Let's Encrypt notifications

**Note:** Use quotes when passing multiple domains: `"domain1.com,domain2.com"`

The script will:
- Request SSL certificate from Let's Encrypt
- Automatically update nginx config for HTTPS (port 443)
- Setup HTTP → HTTPS redirect
- Configure SSL security settings
- Auto-renewal via cron

Your site will now be accessible at `https://your-domain.com` 🔒

**Manage SSL certificates:**
```bash
sudo ./list-ssl.sh      # List all certificates
sudo ./renew-ssl.sh     # Manual renewal
```

### Step 9: Deploy

Push to your main/master branch and GitHub Actions will automatically deploy! 🚀

## 📝 Available Workflows

| Workflow | Use For | Features |
|----------|---------|----------|
| `deploy-nodejs.yml` | Node.js (JavaScript) | Installs deps, runs with PM2 |
| `deploy-nodejs-ts.yml` | TypeScript | Builds, runs with PM2 |
| `deploy-nextjs.yml` | Next.js | Builds, runs with PM2 |
| `deploy-react.yml` | React | Builds, deploys static files |
| `deploy-static-html.yml` | Static HTML | Deploys static files |

## 🔧 Common Commands

### PM2 (Process Manager)
```bash
pm2 list                    # List all processes
pm2 logs [app-name]         # View logs
pm2 restart [app-name]      # Restart app
pm2 reload [app-name]       # Zero-downtime reload
pm2 monit                   # Monitor resources
```

### Nginx
```bash
sudo nginx -t                           # Test config
sudo systemctl reload nginx             # Reload config
sudo systemctl restart nginx            # Restart nginx
sudo tail -f /var/log/nginx/error.log   # View error logs
```

### GitHub Runner
```bash
cd ~/actions-runner
./check-status.sh           # Check status
./view-logs.sh              # View logs
./restart-runner.sh         # Restart runner
```

## 🐛 Troubleshooting

### Check if app is running
```bash
pm2 list
curl http://localhost:3000
```

### Check nginx logs
```bash
sudo tail -f /var/log/nginx/error.log
```

### Check runner status
```bash
sudo systemctl status actions.runner.*
```

### Port already in use
```bash
sudo lsof -i :80
sudo lsof -i :3000
```

## 🔐 Security Best Practices

1. ✅ Use SSH keys only (disable password authentication)
2. ✅ Restrict security groups to necessary ports
3. ✅ Keep system updated: `sudo apt update && sudo apt upgrade`
4. ✅ Use GitHub secrets for sensitive data
5. ✅ Enable HTTPS with Let's Encrypt SSL
6. ✅ Keep `ecosystem.config.js` out of git

## 🔒 Optional: Setup VPN

For secure access to your server, choose one of the VPN solutions:

### Option 1: WireGuard (Recommended - Fast & Modern)

```bash
cd vpn
sudo ./setup-wireguard.sh

# Add clients
sudo ./add-client.sh laptop
sudo ./add-client.sh phone
```

See `VPN-SETUP.md` for complete WireGuard documentation.

### Option 2: OpenVPN (Enterprise Standard)

```bash
cd vpn-openvpn
sudo ./setup-openvpn.sh

# Add clients
sudo ./add-client.sh laptop
sudo ./add-client.sh phone
```

See `OPENVPN-SETUP.md` for complete OpenVPN documentation.

**Which to choose?**
- **WireGuard**: Faster, simpler, better for modern deployments
- **OpenVPN**: More compatible, better firewall traversal, enterprise-proven

## 📚 Additional Resources

- **Nginx Configuration:** See `nginx/README.md`
- **WireGuard VPN:** See `VPN-SETUP.md`
- **OpenVPN:** See `OPENVPN-SETUP.md`
- **PM2 Documentation:** https://pm2.keymetrics.io/
- **GitHub Actions:** https://docs.github.com/actions
- **Let's Encrypt:** https://letsencrypt.org/
- **WireGuard:** https://www.wireguard.com/
- **OpenVPN:** https://openvpn.net/

## 🤝 Contributing

Issues and pull requests are welcome!

## 📄 License

MIT License - Free to use and modify.
