# Deployment Strategy

## 🎯 **Simplified Two-Environment Setup**

We use a simple deployment strategy with two environments:

```
📍 DEVELOPMENT: All branches except main
📍 PRODUCTION:  Main branch only
```

## 🌿 **Branch Deployment Rules**

### **Development Environment**
- **Triggers**: Any branch except `main` (develop, feature/*, appwrite-config, etc.)
- **Appwrite**: Local Docker instance 
- **Project ID**: `intrada-dev`
- **Endpoint**: `http://localhost/v1`
- **Bundle ID**: `com.jonyardley.intrada.development`
- **Hostname**: `localhost`

### **Production Environment**  
- **Triggers**: `main` branch only
- **Appwrite**: Remote production instance
- **Project ID**: From `APPWRITE_PROJECT_ID_PROD` secret (fallback: `intrada-prod`)
- **Endpoint**: From `APPWRITE_ENDPOINT_PROD` secret
- **Bundle ID**: `com.jonyardley.intrada.production`  
- **Hostname**: `intrada.app`

## 🚀 **Deployment Behavior**

### **Pull Requests**
- ✅ Run tests and validation
- ✅ **Dry-run deployment** (shows what would deploy)
- ❌ **No actual deployment**

### **Push to Any Branch (except main)**
- ✅ Run tests and validation
- ✅ **Deploy to Development** (local Docker Appwrite)
- ✅ Full integration testing

### **Push to Main Branch**
- ✅ Run tests and validation  
- ✅ **Deploy to Production** (remote Appwrite)
- ✅ Production verification
- ✅ Integration testing

## ⚙️ **GitHub Setup Required**

### **Secrets** (Repository Settings → Secrets and variables → Actions)

For **Production** deployments, add these secrets:

```bash
APPWRITE_ENDPOINT_PROD=https://your-production-appwrite.com/v1
APPWRITE_PROJECT_ID_PROD=your-production-project-id  
APPWRITE_API_KEY_PROD=your-production-api-key
```

### **No Secrets Needed for Development**
Development uses local Docker and creates projects automatically.

## 📋 **Workflow Examples**

### **Feature Development**
```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes and push
git push origin feature/new-feature
# → Deploys to DEVELOPMENT environment

# Create PR to main
gh pr create --title "Add new feature"
# → Runs dry-run, shows what would deploy to PRODUCTION

# Merge PR
gh pr merge
# → Deploys to PRODUCTION environment
```

### **Hotfix**
```bash
# Create hotfix branch from main
git checkout main
git checkout -b hotfix/critical-fix

# Fix and push
git push origin hotfix/critical-fix  
# → Deploys to DEVELOPMENT environment

# Create PR and merge quickly
gh pr create --title "Critical hotfix"
gh pr merge
# → Deploys to PRODUCTION environment
```

## 🔍 **Workflow Status**

You can monitor deployments in GitHub:

1. **Actions** tab → **Appwrite CI/CD** workflow
2. Each run shows:
   - 🌍 **Environment**: Development or Production
   - 📋 **Branch**: Which branch triggered it
   - 🚀 **Deploy Status**: Will deploy or dry-run only

### **Example Output**
```bash
🌍 Environment: DEVELOPMENT
📋 Branch: feature/new-feature  
🚀 Will deploy: YES

# vs

🌍 Environment: PRODUCTION
📋 Branch: main
🚀 Will deploy: YES
```

## 🛡️ **Safety Features**

### **Automatic Environment Detection**
- No manual configuration needed
- Branch determines environment automatically
- Production requires explicit main branch

### **Dry-Run for PRs** 
- All PRs show deployment preview
- No accidental deployments from PRs
- See exactly what will change

### **Production Protection**
- Only main branch can deploy to production
- Requires secrets to be configured
- Verification after deployment

### **Clean Development**
- Each development deployment uses fresh Docker
- No state leaks between runs
- Complete cleanup after each run

## 🔧 **Local Development**

For local development, use the Makefile:

```bash
# Start local environment
make setup

# Deploy changes locally  
make dev-deploy

# Check status
make status

# Clean up
make teardown
```

## 📈 **Monitoring**

### **Development Deployments**
- Check GitHub Actions logs
- Local Appwrite console: `http://localhost/console`

### **Production Deployments**  
- Check GitHub Actions logs
- Production Appwrite console
- Monitor application metrics

## 🚨 **Troubleshooting**

### **Development Issues**
- Docker not starting: Check Docker Desktop
- Port conflicts: Stop other local services
- API key issues: Workflow recreates them automatically

### **Production Issues**
- Check secrets are configured correctly
- Verify production Appwrite is accessible
- Check API key has required permissions

### **Common Fixes**
```bash
# Re-run failed deployment
gh workflow run "Appwrite CI/CD" --ref main

# Check workflow logs
gh run list --workflow="Appwrite CI/CD"
gh run view <run-id> --log
```

## 🎯 **Next Steps**

This simple setup gives you:
- ✅ Automatic deployments
- ✅ Environment isolation  
- ✅ Safety through dry-runs
- ✅ Easy troubleshooting

As your needs grow, you can extend this to add staging environments, manual approval gates, or more sophisticated deployment strategies.