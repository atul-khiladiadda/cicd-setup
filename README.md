# CI/CD Setup Scripts for Ubuntu EC2 with GitHub Actions

This repository contains scripts to set up a CI/CD pipeline on an Ubuntu EC2 instance using GitHub Actions self-hosted runner for Node.js projects with PM2.

## 📁 Project Structure

```
cicd-setup/
├── setup-dependencies.sh      # Install Node.js, PM2, and system dependencies
├── setup-runner.sh            # Install and configure GitHub Actions runner
├── nginx/
│   ├── proxy.conf.example     # Nginx config for Node.js/TypeScript/Next.js
│   ├── static.conf.example    # Nginx config for static HTML/React sites
│   └── README.md              # Nginx setup guide
├── scripts/
│   └── setup-mongodb.sh       # MongoDB installation (optional)
├── ssl/
│   ├── setup-certbot.sh       # Install and configure Certbot
│   ├── obtain-ssl.sh          # Obtain SSL certificate
│   ├── obtain-ssl-static.sh   # SSL for static sites
│   ├── obtain-ssl-proxy.sh    # SSL for reverse proxy
│   ├── renew-ssl.sh           # Renew SSL certificates
│   ├── revoke-ssl.sh          # Revoke SSL certificates
│   └── list-ssl.sh            # List all SSL certificates
├── workflows/
│   ├── deploy-nodejs.yml      # Workflow for Node.js apps
│   ├── deploy-nodejs-ts.yml   # Workflow for TypeScript apps
│   ├── deploy-nextjs.yml      # Workflow for Next.js apps
│   ├── deploy-react.yml       # Workflow for React apps
│   └── deploy-static-html.yml # Workflow for static sites
└── README.md                  # This file
```

## 🚀 Quick Start

### Step 1: Launch EC2 Instance

1. Launch an Ubuntu 22.04 LTS (or later) EC2 instance
2. Configure security groups:
   - SSH (port 22) - your IP
   - HTTP (port 80) - 0.0.0.0/0
   - HTTPS (port 443) - 0.0.0.0/0
   - Your app port (e.g., 3000) - optional

3. SSH into your instance:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

### Step 2: Upload Scripts

```bash
# From your local machine
scp -i your-key.pem -r cicd-setup ubuntu@your-ec2-ip:~/
```

Or clone/download directly on the EC2:
```bash
# On EC2 instance
git clone https://github.com/your-username/cicd-setup.git
cd cicd-setup
chmod +x *.sh
```

### Step 3: Install Dependencies

```bash
# Run as root
sudo ./setup-dependencies.sh

# Or specify Node.js version
sudo ./setup-dependencies.sh 20
```

This installs:
- Node.js (specified version, default: 20)
- npm
- PM2 (with startup configuration)
- Yarn
- Nginx
- Build tools
- Git

### Step 4: Get GitHub Runner Token

1. Go to your GitHub repository
2. Navigate to **Settings** → **Actions** → **Runners**
3. Click **New self-hosted runner**
4. Copy the **token** shown in the configuration section

### Step 5: Setup GitHub Actions Runner

```bash
# Run as ubuntu user (NOT with sudo - the script handles sudo internally where needed)
./setup-runner.sh https://github.com/your-username/your-repo YOUR_TOKEN

# With custom name and labels
./setup-runner.sh https://github.com/your-username/your-repo YOUR_TOKEN prod-runner "self-hosted,ubuntu,production"
```

### Step 6: Setup Nginx for Your Application

Choose the appropriate nginx configuration file based on your project type:

#### For Node.js/TypeScript/Next.js Applications (Reverse Proxy)

```bash
# Copy the proxy configuration template
sudo cp nginx/proxy.conf.example /etc/nginx/sites-available/your-app

# Edit the configuration
sudo nano /etc/nginx/sites-available/your-app

# Update these values:
# - server_name: example.com www.example.com
# - upstream port: 127.0.0.1:3000 (change port if needed)

# Enable the site
sudo ln -s /etc/nginx/sites-available/your-app /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

#### For Static Websites (HTML/React/Vue/Angular)

```bash
# Copy the static configuration template
sudo cp nginx/static.conf.example /etc/nginx/sites-available/your-site

# Edit the configuration
sudo nano /etc/nginx/sites-available/your-site

# Update these values:
# - server_name: example.com www.example.com
# - root: /home/ubuntu/app-deploy/your-site

# Enable the site
sudo ln -s /etc/nginx/sites-available/your-site /etc/nginx/sites-enabled/

# Test and reload
sudo nginx -t && sudo systemctl reload nginx
```

See `nginx/README.md` for detailed instructions and troubleshooting.

### Step 7: Configure Your Repository

1. **Choose and copy the appropriate workflow file** to your repository:
   ```bash
   # In your project repository
   mkdir -p .github/workflows
   
   # For Node.js (JavaScript)
   cp /path/to/cicd-setup/workflows/deploy-nodejs.yml .github/workflows/deploy.yml
   
   # For TypeScript
   cp /path/to/cicd-setup/workflows/deploy-nodejs-ts.yml .github/workflows/deploy.yml
   
   # For Next.js
   cp /path/to/cicd-setup/workflows/deploy-nextjs.yml .github/workflows/deploy.yml
   
   # For React
   cp /path/to/cicd-setup/workflows/deploy-react.yml .github/workflows/deploy.yml
   
   # For Static HTML
   cp /path/to/cicd-setup/workflows/deploy-static-html.yml .github/workflows/deploy.yml
   ```

2. **Add repository secrets** (Settings → Secrets and variables → Actions):
   - `ENV_FILE` - Contents of your `.env` file (optional)

3. **Create ecosystem.config.js** in your project root (for Node.js/Next.js projects):
   ```javascript
   module.exports = {
     apps: [{
       name: 'my-app',
       script: './index.js',  // or './dist/index.js' for TypeScript
       instances: 'max',
       exec_mode: 'cluster',
       env_production: {
         NODE_ENV: 'production',
         PORT: 3000
       }
     }]
   };
   ```
   
   **Note:** Add `ecosystem.config.js` to your `.gitignore` to keep production config separate

## 📋 Script Details

### `setup-dependencies.sh`

Installs all required system dependencies for running Node.js applications.

```bash
sudo ./setup-dependencies.sh [node_version]
```

| Argument | Description | Default |
|----------|-------------|---------|
| `node_version` | Node.js major version to install | 20 |

### `setup-runner.sh`

Installs and configures the GitHub Actions self-hosted runner.

```bash
./setup-runner.sh <github_repo_url> <runner_token> [runner_name] [labels]
```

| Argument | Description | Default |
|----------|-------------|---------|
| `github_repo_url` | Full GitHub repository URL | Required |
| `runner_token` | Registration token from GitHub | Required |
| `runner_name` | Name for the runner | hostname |
| `labels` | Comma-separated labels | self-hosted,ubuntu,ec2 |

### Nginx Configuration Files (`nginx/` folder)

#### `proxy.conf.example`

Simple nginx configuration for **Node.js, TypeScript, and Next.js** applications.

**Features:**
- Reverse proxy to your application (port 3000)
- WebSocket support (for Next.js HMR)
- Request forwarding headers
- 300s timeout for long requests
- 50MB upload limit

**Usage:**
```bash
sudo cp nginx/proxy.conf.example /etc/nginx/sites-available/your-app
sudo nano /etc/nginx/sites-available/your-app
# Edit: server_name, upstream port
sudo ln -s /etc/nginx/sites-available/your-app /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

#### `static.conf.example`

Simple nginx configuration for **static websites** (HTML, React, Vue, Angular).

**Features:**
- Serves static files directly
- SPA routing support (fallback to index.html)
- Cache static assets for 1 year
- Never cache HTML files
- Gzip compression

**Usage:**
```bash
sudo cp nginx/static.conf.example /etc/nginx/sites-available/your-site
sudo nano /etc/nginx/sites-available/your-site
# Edit: server_name, root path
sudo ln -s /etc/nginx/sites-available/your-site /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

See `nginx/README.md` for detailed documentation.

## 🔧 Configuration

### PM2 Ecosystem File

Create an `ecosystem.config.js` in your project root:

```javascript
module.exports = {
  apps: [{
    name: 'my-app',
    script: './dist/index.js',
    instances: 'max',
    exec_mode: 'cluster',
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000
    }
  }]
};
```

### Environment Variables

You can set environment variables in three ways:

1. **GitHub Secrets** - Store your `.env` file content in `ENV_FILE` secret
2. **ecosystem.config.js** - Define env variables in PM2 config
3. **System environment** - Export in `/etc/environment` or user's `.bashrc`

### Nginx Configuration

Two sample configuration files are provided in the `nginx/` folder:

1. **`nginx/proxy.conf.example`** - For Node.js/TypeScript/Next.js (reverse proxy)
2. **`nginx/static.conf.example`** - For static sites (HTML/React/Vue/Angular)

These are simplified, production-ready configurations. Copy the appropriate file to `/etc/nginx/sites-available/`, edit your domain and settings, enable the site, test, and reload nginx.

See `nginx/README.md` for complete documentation.

### SSL/HTTPS Configuration

After setting up Nginx and configuring DNS, secure your site with SSL (free Let's Encrypt):

```bash
# Setup Certbot (one-time installation)
cd ssl
sudo ./setup-certbot.sh

# Obtain SSL certificate (will prompt for domain)
sudo ./obtain-ssl.sh

# Or use specific scripts for your setup:
sudo ./obtain-ssl-proxy.sh    # For Node.js/Next.js (reverse proxy)
sudo ./obtain-ssl-static.sh   # For static HTML/React sites

# These scripts will:
# - Obtain SSL certificate from Let's Encrypt
# - Automatically update your nginx config for HTTPS (port 443)
# - Set up HTTP to HTTPS redirect
# - Configure SSL security settings

# Manage certificates:
sudo ./list-ssl.sh      # List all SSL certificates
sudo ./renew-ssl.sh     # Renew certificates (auto-setup in cron)
sudo ./revoke-ssl.sh    # Revoke a certificate if needed
```

## 📊 Monitoring & Management

### PM2 Commands

```bash
# View all processes
pm2 list

# View logs
pm2 logs [app-name]

# Monitor resources
pm2 monit

# Restart application
pm2 restart [app-name]

# Reload with zero downtime
pm2 reload [app-name]

# Stop application
pm2 stop [app-name]

# Delete from PM2
pm2 delete [app-name]
```

### Runner Commands

```bash
# Check runner status
cd ~/actions-runner && ./check-status.sh

# View runner logs
cd ~/actions-runner && ./view-logs.sh

# Restart runner
cd ~/actions-runner && ./restart-runner.sh
```

## 🔐 Security Recommendations

1. **Use SSH keys** - Never use password authentication
2. **Restrict security groups** - Only open necessary ports
3. **Keep system updated** - Run `sudo apt update && sudo apt upgrade` regularly
4. **Use secrets** - Never commit sensitive data to repositories
5. **Enable firewall** - UFW is configured by the setup script
6. **Use HTTPS** - Configure SSL with Let's Encrypt for production

## 🐛 Troubleshooting

### Runner not connecting

```bash
# Check runner service status
sudo systemctl status actions.runner.*

# View runner logs
sudo journalctl -u actions.runner.* -f

# Restart runner service
cd ~/actions-runner && sudo ./svc.sh restart
```

### PM2 process not starting

```bash
# Check PM2 logs
pm2 logs your-app --lines 100

# Check if port is in use
sudo lsof -i :3000

# Verify environment
pm2 env your-app
```

### Nginx issues

```bash
# Test configuration
sudo nginx -t

# Check error logs
sudo tail -f /var/log/nginx/error.log

# Reload configuration
sudo systemctl reload nginx
```

## 📝 Workflow Customization

Each workflow file can be customized:

- **Branches** - Change trigger branches (main, master, prod, etc.)
- **Node version** - Update in `setup-node` step
- **Environment** - Configure `APP_BASE_DIR` and `PROJECT_NAME` variables
- **Build commands** - Customize build steps for your project
- **PM2 configuration** - Workflows respect your ecosystem.config.js file

### Important Notes

1. **Ecosystem Config**: The workflows will NOT create ecosystem.config.js automatically. You must create and maintain your own in the deployment directory on the server.

2. **Gitignore**: Add to your `.gitignore`:
   ```
   ecosystem.config.js
   .env
   .env.local
   ```

3. **File Preservation**: Workflows exclude these files from sync to preserve server configs:
   - `ecosystem.config.js`
   - `.env` files
   - `node_modules`
   - `.next` (for Next.js)

## 🌐 DNS Configuration

After setting up nginx, you need to point your domain to your EC2 instance.

### Get Your EC2 IP Address

```bash
# On your EC2 instance
curl ifconfig.me
# Or
hostname -I | awk '{print $1}'
```

### Configure DNS Records

Log in to your domain registrar (GoDaddy, Namecheap, Cloudflare, etc.) and add DNS records:

#### For Root Domain (example.com)
```
Type: A
Name: @ (or leave empty for root)
Value: [Your EC2 IP Address]
TTL: 3600 (or default)
```

#### For Subdomain (api.example.com, www.example.com)
```
Type: A
Name: api (or www, or any subdomain)
Value: [Your EC2 IP Address]
TTL: 3600 (or default)
```

#### For www Redirect (optional)
If you want both www and non-www to work, add:
```
Type: A
Name: www
Value: [Your EC2 IP Address]
TTL: 3600
```
Then uncomment the www redirect block in your nginx config.

### DNS Propagation

- **Typical Time**: 15-30 minutes
- **Maximum Time**: Up to 48 hours
- **Check Propagation**: 
  - Command: `dig your-domain.com`
  - Online: https://dnschecker.org/

### Testing

Once DNS propagates:
```bash
# Test DNS resolution
dig your-domain.com

# Test HTTP connection (on your server)
curl http://your-domain.com

# Visit in browser
http://your-domain.com
```

## 🤝 Contributing

Feel free to submit issues and pull requests for improvements.

## 📄 License

MIT License - feel free to use and modify for your projects.

