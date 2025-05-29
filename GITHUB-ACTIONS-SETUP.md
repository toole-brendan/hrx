# GitHub Actions Deployment Setup Guide

This guide will help you set up automated deployments for HandReceipt using GitHub Actions.

## 🎯 **What This Does**

The GitHub Actions workflow automatically:
1. **Detects your current setup** (DNS working? SSL working?)
2. **Builds frontend** with the correct API URL (DNS or direct IP)
3. **Deploys frontend** to S3 with proper caching
4. **Deploys backend** to Lightsail (optional)
5. **Sets up SSL** automatically when DNS is ready
6. **Runs health checks** to verify everything works
7. **"Gets around" DNS issues** by using direct IP when needed

## 🔧 **Prerequisites**

### 1. GitHub Repository
- Push your HandReceipt code to GitHub
- Enable GitHub Actions (usually enabled by default)

### 2. AWS Credentials
- Your existing AWS credentials (same ones you use locally)
- SSH access to your Lightsail instance

## 🔑 **Required GitHub Secrets**

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add:

### **AWS Secrets:**
```
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```
*(Use the same credentials you have configured locally)*

### **Lightsail SSH Key:**
```
LIGHTSAIL_SSH_PRIVATE_KEY
```
*(Your SSH private key for accessing the Lightsail instance)*

### **Admin Email (for SSL certificates):**
```
ADMIN_EMAIL
```
*(Your email for Let's Encrypt SSL certificates)*

## 📋 **Step-by-Step Setup**

### **Step 1: Get Your SSH Private Key**

You'll need the private key that corresponds to the public key on your Lightsail instance:

#### Option A: Use Existing Key
```bash
# If you already have a key for Lightsail
cat ~/.ssh/your_lightsail_key
```

#### Option B: Create New Key
```bash
# Generate new SSH key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/handreceipt_lightsail

# Copy public key to clipboard
cat ~/.ssh/handreceipt_lightsail.pub
```

Then add the public key to your Lightsail instance:
1. SSH to your instance
2. Add the public key to `~/.ssh/authorized_keys`

### **Step 2: Add GitHub Secrets**

1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret** for each:

```
Name: AWS_ACCESS_KEY_ID
Value: [Your AWS Access Key]

Name: AWS_SECRET_ACCESS_KEY  
Value: [Your AWS Secret Key]

Name: LIGHTSAIL_SSH_PRIVATE_KEY
Value: [Contents of your private key file - include -----BEGIN and -----END lines]

Name: ADMIN_EMAIL
Value: [Your email address]
```

### **Step 3: Test the Workflow**

1. Go to **Actions** tab in your GitHub repository
2. Click **Deploy HandReceipt to Production**
3. Click **Run workflow**
4. Choose your options:
   - ✅ **Deploy frontend**: Deploy to S3/CloudFront
   - ✅ **Deploy backend**: Deploy to Lightsail  
   - ❌ **Force direct IP**: Only if DNS isn't working
   - ❌ **Skip SSL setup**: Only if you don't want SSL yet

## 🎮 **How to Use**

### **Regular Deployment (Recommended)**
```
Deploy frontend: ✅ YES
Deploy backend: ✅ YES  
Force direct IP: ❌ NO
Skip SSL setup: ❌ NO
```

**What happens:**
- Workflow checks if DNS is working
- If DNS works → uses `https://api.handreceipt.com/api`
- If DNS doesn't work → uses `http://44.193.254.155:8080/api`
- Sets up SSL automatically when DNS is ready

### **Frontend Only Deployment**
```
Deploy frontend: ✅ YES
Deploy backend: ❌ NO
Force direct IP: ❌ NO  
Skip SSL setup: ❌ NO
```

**Use when:** You only changed frontend code

### **Backend Only Deployment**
```
Deploy frontend: ❌ NO
Deploy backend: ✅ YES
Force direct IP: ❌ NO
Skip SSL setup: ❌ NO
```

**Use when:** You only changed backend code

### **Emergency Direct IP Mode**
```
Deploy frontend: ✅ YES
Deploy backend: ❌ NO
Force direct IP: ✅ YES
Skip SSL setup: ✅ YES
```

**Use when:** DNS is broken and you need to deploy immediately

## 🔍 **Understanding the Output**

The workflow will show you:

```bash
📋 Deployment Summary:
DNS Working: true/false
SSL Working: true/false  
API URL: https://api.handreceipt.com/api (or direct IP)
```

### **Scenarios:**

#### **✅ Perfect Setup (DNS + SSL working)**
```
DNS Working: true
SSL Working: true
API URL: https://api.handreceipt.com/api
```

#### **🌐 DNS Working, SSL Not Set Up Yet**
```
DNS Working: true
SSL Working: false
API URL: http://api.handreceipt.com/api
```
*Next run will set up SSL automatically*

#### **⚡ DNS Not Working (Fallback Mode)**
```
DNS Working: false
SSL Working: false
API URL: http://44.193.254.155:8080/api
```
*Will automatically switch to DNS when it starts working*

## 🚨 **Troubleshooting**

### **"DNS not working yet"**
- Your A record might not have propagated
- Wait up to 24 hours for DNS propagation
- Workflow will use direct IP in the meantime

### **"SSL setup failed"**
- DNS must be working first
- Check that `api.handreceipt.com` resolves correctly
- Re-run workflow once DNS is working

### **"Backend deployment failed"**
- Check your SSH key is correct
- Verify your Lightsail instance is running
- Check the workflow logs for specific errors

### **"Frontend still uses old API"**
- Clear your browser cache
- CloudFront cache takes time to invalidate
- Force refresh: Ctrl+F5 or Cmd+Shift+R

## 🔄 **Workflow Progression**

Here's how the setup progresses over time:

### **Day 1: Initial Setup (DNS not ready)**
```bash
# Workflow automatically uses:
VITE_API_URL=http://44.193.254.155:8080/api

# Your app works immediately with direct IP
```

### **Day 1-2: DNS Propagates**
```bash
# Workflow detects DNS and switches to:
VITE_API_URL=http://api.handreceipt.com/api

# Still works, now with proper domain
```

### **Day 2: SSL Gets Set Up**
```bash
# Workflow sets up SSL and switches to:
VITE_API_URL=https://api.handreceipt.com/api

# Now fully secure with HTTPS
```

## 🎉 **Benefits**

1. **Zero downtime**: Always uses working API endpoint
2. **Smart fallbacks**: Direct IP when DNS isn't ready
3. **Auto SSL**: Sets up HTTPS when DNS is ready
4. **Selective deployment**: Frontend or backend independently
5. **Health checks**: Verifies everything works
6. **No manual work**: Handles the DNS transition automatically

## 📱 **Quick Commands**

Test your setup locally:
```bash
# Test the current API connection
./test-api-connection.sh

# Deploy manually (for comparison)
./deploy-frontend.sh
```

Check workflow status:
- Go to **Actions** tab in GitHub
- Click on latest workflow run
- Check each job's logs

## 🔗 **Next Steps**

1. **Set up the secrets** as described above
2. **Run your first deployment** with both frontend and backend
3. **Monitor the output** to see current DNS/SSL status
4. **Re-run periodically** as DNS propagates and SSL gets set up

The workflow will handle the transition from direct IP → DNS → HTTPS automatically! 