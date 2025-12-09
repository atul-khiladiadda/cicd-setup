/**
 * PM2 Ecosystem Configuration File
 * 
 * Copy this file to your project root as ecosystem.config.js
 * and customize the settings for your application.
 * 
 * Documentation: https://pm2.keymetrics.io/docs/usage/application-declaration/
 */

module.exports = {
  apps: [
    {
      // Application name (used by PM2 to identify the process)
      name: 'my-app', // Change this to your project name

      // Entry point of your application
      script: './dist/index.js', // Adjust based on your build output

      // Number of instances (use 'max' for cluster mode with all CPUs)
      instances: 'max',

      // Execution mode: 'cluster' for load balancing, 'fork' for single instance
      exec_mode: 'cluster',

      // Automatically restart if the app crashes
      autorestart: true,

      // Watch for file changes (disable in production)
      watch: false,

      // Maximum memory before restart
      max_memory_restart: '500M',

      // Environment variables for all environments
      env: {
        NODE_ENV: 'development',
        PORT: 3000,
      },

      // Production environment variables
      env_production: {
        NODE_ENV: 'production',
        PORT: 3000,
      },

      // Staging environment variables
      env_staging: {
        NODE_ENV: 'staging',
        PORT: 3000,
      },

      // Log configuration
      log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
      error_file: '/home/ubuntu/logs/my-app-error.log',
      out_file: '/home/ubuntu/logs/my-app-out.log',
      merge_logs: true,

      // Graceful shutdown
      kill_timeout: 5000,
      wait_ready: true,
      listen_timeout: 10000,

      // Restart delay between crashes
      restart_delay: 4000,

      // Maximum number of restarts within a time window
      max_restarts: 10,
      min_uptime: '10s',

      // Source maps support (for TypeScript/transpiled code)
      source_map_support: true,

      // Node.js arguments
      node_args: [
        '--max-old-space-size=512',
      ],
    },
  ],

  // Deployment configuration (optional - for PM2 deploy feature)
  deploy: {
    production: {
      user: 'ubuntu',
      host: 'your-ec2-ip-or-hostname',
      ref: 'origin/main',
      repo: 'git@github.com:username/repo.git',
      path: '/home/ubuntu/app-deploy/my-app',
      'post-deploy': 'npm install && npm run build && pm2 reload ecosystem.config.js --env production',
    },
  },
};

