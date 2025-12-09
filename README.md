# CI/CD Setup Scripts for Ubuntu EC2 with GitHub Actions

This repository contains scripts to set up a CI/CD pipeline on an Ubuntu EC2 instance using GitHub Actions self-hosted runner for Node.js projects with PM2.

## 📁 Project Structure

```
cicd-setup/
├── setup-dependencies.sh      # Install Node.js, PM2, and system dependencies
├── setup-runner.sh            # Install and configure GitHub Actions runner
├── deploy.sh                  # Deployment script for PM2 applications
├── workflows/
│   └── deploy.yml             # GitHub Actions workflow (copy to .github/workflows/)
├── ecosystem.config.example.js # PM2 ecosystem config example
├── nginx.conf.example         # Nginx reverse proxy configuration
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
# Run as ubuntu user (not root!)
./setup-runner.sh https://github.com/your-username/your-repo YOUR_TOKEN

# With custom name and labels
./setup-runner.sh https://github.com/your-username/your-repo YOUR_TOKEN prod-runner "self-hosted,ubuntu,production"
```

### Step 6: Configure Your Repository

1. **Copy the workflow file** to your repository:
   ```bash
   # In your project repository
   mkdir -p .github/workflows
   cp /path/to/cicd-setup/workflows/deploy.yml .github/workflows/
   ```

2. **Add repository secrets** (Settings → Secrets and variables → Actions):
   - `ENV_FILE` - Contents of your `.env` file (optional)

3. **Configure PM2** (optional but recommended):
   ```bash
   cp /path/to/cicd-setup/ecosystem.config.example.js ecosystem.config.js
   # Edit ecosystem.config.js with your settings
   ```

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

### `deploy.sh`

Deploys a Node.js application using PM2.

```bash
./deploy.sh <project_name> [environment]
```

| Argument | Description | Default |
|----------|-------------|---------|
| `project_name` | Name of the project | Required |
| `environment` | Deployment environment | production |

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

For production deployments with a domain:

```bash
# Copy and edit the nginx config
sudo cp nginx.conf.example /etc/nginx/sites-available/your-app
sudo nano /etc/nginx/sites-available/your-app

# Enable the site
sudo ln -s /etc/nginx/sites-available/your-app /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

For SSL with Let's Encrypt:
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
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

Edit `.github/workflows/deploy.yml` to customize:

- **Branches** - Change `main` to your deployment branch
- **Node version** - Update in `setup-node` step
- **Environment** - Add staging/production configurations
- **Tests** - Enable/disable test step
- **Notifications** - Add Slack/Discord notifications

## 🤝 Contributing

Feel free to submit issues and pull requests for improvements.

## 📄 License

MIT License - feel free to use and modify for your projects.

