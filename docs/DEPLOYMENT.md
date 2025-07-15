# Deployment Guide

This guide covers deploying the Intrada application to production using PostgreSQL and Fly.io.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Production Setup                          │
├─────────────────────────────────────────────────────────────┤
│  Web App (Leptos)  │  Server API (Rust)  │  Database        │
│  Static hosting    │  Fly.io             │  PostgreSQL      │
│  (Vercel/Netlify)  │  fly.toml           │  Fly.io Postgres │
└─────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Fly.io account](https://fly.io/docs/hands-on/sign-up/)
- [Fly CLI installed](https://fly.io/docs/hands-on/install-flyctl/)
- Database backup (if migrating)

## Server Deployment (Fly.io)

### 1. Initial Setup

```bash
# Login to Fly.io
fly auth login

# Navigate to server directory
cd server

# Create fly.toml if it doesn't exist
fly launch --no-deploy

# Create PostgreSQL database
fly postgres create --name intrada-db

# Get database URL
fly postgres connect --database intrada-db
```

### 2. Configure Environment Variables

```bash
# Set database URL
fly secrets set DATABASE_URL="postgresql://user:password@host:5432/database"

# Set other environment variables
fly secrets set RUST_LOG=info
fly secrets set PORT=8080
```

### 3. Deploy Server

```bash
# Deploy to Fly.io
fly deploy

# Check deployment status
fly status
fly logs
```

### 4. Run Database Migrations

```bash
# Connect to the deployed app
fly ssh console

# Run migrations
cd /app && sqlx migrate run
```

## Web App Deployment

### Option 1: Static Hosting (Vercel)

```bash
cd web-leptos

# Build for production
npm run build

# Deploy to Vercel
npm install -g vercel
vercel deploy --prod
```

### Option 2: Fly.io Hosting

```bash
cd web-leptos

# Create fly.toml for web app
fly launch --no-deploy

# Deploy web app
fly deploy
```

## Environment Configuration

### Production Environment Variables

**Server (`server/.env.production`)**:
```bash
DATABASE_URL=postgresql://user:password@host:5432/database
RUST_LOG=info
PORT=8080
```

**Web App (`web-leptos/.env.production`)**:
```bash
VITE_API_URL=https://your-api.fly.dev
```

### Development Environment Variables

**Server (`server/.env.local`)**:
```bash
DATABASE_URL=postgresql://localhost:5432/intrada_dev
RUST_LOG=debug
PORT=3000
```

**Web App (`web-leptos/.env.local`)**:
```bash
VITE_API_URL=http://localhost:3000
```

## Database Management

### Creating Database

```bash
# Create production database
fly postgres create --name intrada-prod-db --region ord

# Create development database
fly postgres create --name intrada-dev-db --region ord

# Connect to database
fly postgres connect --database intrada-prod-db
```

### Running Migrations

```bash
# Install sqlx-cli
cargo install sqlx-cli

# Run migrations
cd server
sqlx migrate run --database-url $DATABASE_URL
```

### Database Backup

```bash
# Create backup
fly postgres backup --database intrada-prod-db

# Restore from backup
fly postgres restore --database intrada-prod-db --from-backup backup-id
```

## CI/CD Pipeline

### GitHub Actions Setup

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]

jobs:
  deploy-server:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Fly.io
        uses: superfly/flyctl-actions/setup-flyctl@master
        
      - name: Deploy server
        run: |
          cd server
          flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
          
  deploy-web:
    runs-on: ubuntu-latest
    needs: deploy-server
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Build and deploy web app
        run: |
          cd web-leptos
          npm install
          npm run build
          npx vercel --prod --token ${{ secrets.VERCEL_TOKEN }}
```

### Required Secrets

Add these secrets to your GitHub repository:

- `FLY_API_TOKEN`: Fly.io API token
- `VERCEL_TOKEN`: Vercel deployment token (if using Vercel)
- `DATABASE_URL`: Production database URL

## Monitoring and Logging

### Application Logs

```bash
# View server logs
fly logs --app your-server-app

# Stream logs in real-time
fly logs --app your-server-app --follow

# View specific number of lines
fly logs --app your-server-app --lines 100
```

### Database Monitoring

```bash
# Check database status
fly status --app intrada-prod-db

# Monitor database metrics
fly dashboard --app intrada-prod-db
```

### Performance Monitoring

```bash
# Check application metrics
fly metrics --app your-server-app

# View resource usage
fly status --app your-server-app
```

## Scaling

### Server Scaling

```bash
# Scale server instances
fly scale count 2 --app your-server-app

# Scale server resources
fly scale vm shared-cpu-2x --app your-server-app
fly scale memory 1024 --app your-server-app
```

### Database Scaling

```bash
# Scale database
fly postgres scale --database intrada-prod-db --vm-size shared-cpu-2x
```

## Security

### SSL/TLS

Fly.io automatically provides SSL certificates. For custom domains:

```bash
# Add custom domain
fly certs create your-domain.com

# Check certificate status
fly certs list
```

### Environment Security

- Use `fly secrets` for sensitive data
- Never commit secrets to version control
- Use environment-specific configurations
- Regularly rotate API keys and passwords

## Troubleshooting

### Common Issues

**Database Connection Failed**:
```bash
# Check database status
fly status --app intrada-prod-db

# Verify DATABASE_URL
fly secrets list --app your-server-app

# Test connection
fly ssh console --app your-server-app
psql $DATABASE_URL
```

**Server Won't Start**:
```bash
# Check logs
fly logs --app your-server-app

# Verify configuration
fly ssh console --app your-server-app
env | grep DATABASE_URL
```

**Web App Not Loading**:
```bash
# Check API endpoint
curl https://your-api.fly.dev/health

# Verify environment variables
echo $VITE_API_URL
```

### Debug Commands

```bash
# SSH into server
fly ssh console --app your-server-app

# Run health check
curl http://localhost:8080/health

# Check application status
fly status --app your-server-app
```

## Rollback

### Server Rollback

```bash
# List deployments
fly releases --app your-server-app

# Rollback to previous version
fly rollback --app your-server-app
```

### Web App Rollback

```bash
# Vercel rollback
vercel rollback

# Or redeploy previous version
git checkout previous-commit
cd web-leptos && npm run build && vercel deploy --prod
```

## Best Practices

1. **Use staging environment** for testing changes
2. **Monitor logs** after each deployment
3. **Run health checks** before marking deployment complete
4. **Keep database backups** before major changes
5. **Use environment-specific configurations**
6. **Test rollback procedures** regularly

## Cost Optimization

- Use shared CPU instances for development
- Scale down non-production environments
- Monitor resource usage regularly
- Use connection pooling for database
- Implement caching where appropriate

---

*This guide assumes you're using Fly.io for hosting. Adjust commands and configurations for other cloud providers as needed.*