# HandReceipt API DNS & SSL Setup Guide

## 🌐 Step 1: Create DNS A Record

### Option A: Google Cloud Console
1. Go to: https://console.cloud.google.com/
2. Search for "Cloud DNS"
3. Find your `handreceipt.com` zone
4. Click "Add Record Set"
5. Configure:
   ```
   DNS name: api.handreceipt.com
   Resource record type: A
   TTL: 300
   IPv4 address: 44.193.254.155
   ```
6. Click "Create"

### Option B: Google Domains Dashboard  
1. Go to: https://domains.google.com/
2. Find `handreceipt.com` → Click "Manage"
3. Go to "DNS" tab
4. Scroll to "Custom resource records"
5. Add:
   ```
   Host name: api
   Type: A
   TTL: 300
   Data: 44.193.254.155
   ```
6. Click "Add"

## ⏳ Step 2: Wait for DNS Propagation
Test when ready (5-15 minutes):
```bash
nslookup api.handreceipt.com
```
Should return: `44.193.254.155`

## 🔒 Step 3: SSL Certificate (Let's Encrypt - Easiest)

### SSH to your Lightsail instance:
1. Go to Lightsail console: https://lightsail.aws.amazon.com/
2. Click on `handreceipt-primary` instance
3. Click "Connect using SSH"

### Install and configure SSL:
```bash
# Update system
sudo apt update

# Install certbot
sudo apt install certbot python3-certbot-nginx -y

# Generate SSL certificate
sudo certbot --nginx -d api.handreceipt.com

# Follow the prompts:
# - Enter email for urgent renewal notices
# - Accept terms of service (Y)
# - Share email with EFF (Y/N - your choice)  
# - Choose option 2: "Redirect HTTP to HTTPS"
```

### Set up auto-renewal:
```bash
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

## 🔧 Step 4: Update Frontend Configuration

### Create production environment file:
```bash
cd /path/to/your/web/directory
echo "VITE_API_URL=https://api.handreceipt.com/api" > .env.production
```

### Rebuild and deploy:
```bash
./deploy-frontend.sh
```

## ✅ Step 5: Test Everything

### Test DNS:
```bash
nslookup api.handreceipt.com
# Should return: 44.193.254.155
```

### Test SSL:
```bash
curl -I https://api.handreceipt.com/api/auth/me
# Should return 401 Unauthorized with HTTPS
```

### Test in browser:
1. Visit: https://handreceipt.com
2. Open Developer Tools → Network tab
3. Try to login or perform actions
4. Verify API calls go to `https://api.handreceipt.com/api/`

## 🚨 Troubleshooting

### If DNS doesn't work:
- Wait longer (up to 24 hours)
- Check if you added the record correctly
- Try: `dig api.handreceipt.com`

### If SSL fails:
- Ensure DNS is working first
- Check nginx config: `sudo nginx -t`
- Check certbot logs: `sudo tail -f /var/log/letsencrypt/letsencrypt.log`

### If frontend still uses old API:
- Clear browser cache
- Wait for CloudFront cache to expire (up to 24 hours)
- Force refresh: Ctrl+F5 or Cmd+Shift+R

## 🎯 Quick Summary

1. **DNS**: Add A record `api.handreceipt.com` → `44.193.254.155`
2. **SSL**: SSH to Lightsail, run `sudo certbot --nginx -d api.handreceipt.com`
3. **Frontend**: Update `.env.production` to `https://api.handreceipt.com/api`
4. **Deploy**: Run `./deploy-frontend.sh`

Total time: ~30 minutes (mostly waiting for DNS) 