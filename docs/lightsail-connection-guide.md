# Lightsail Backend Connection Guide

This guide covers all necessary configurations to connect your web and iOS applications to your AWS Lightsail backend.

## Prerequisites

- AWS Lightsail instance running with HandReceipt backend
- PostgreSQL database configured
- Domain name (recommended) or static IP address
- SSL certificate (for HTTPS - recommended)

## 1. Backend Configuration

### Update Environment Variables

1. SSH into your Lightsail instance:
```bash
ssh -i your-key.pem ubuntu@your-lightsail-ip
```

2. Update the systemd service file:
```bash
sudo nano /etc/systemd/system/handreceipt.service
```

3. Add these environment variables:
```ini
[Service]
Environment="DATABASE_URL=postgresql://username:password@localhost/handreceipt"
Environment="JWT_SECRET=your-very-secure-jwt-secret-key"
Environment="SESSION_SECRET=your-very-secure-session-secret"
Environment="CORS_ORIGINS=https://your-domain.com,capacitor://localhost"
Environment="HANDRECEIPT_SERVER_PORT=8080"
```

4. Restart the service:
```bash
sudo systemctl daemon-reload
sudo systemctl restart handreceipt
sudo systemctl status handreceipt
```

### CORS Configuration

The backend's CORS middleware has been updated to:
- Accept origins from environment variable `CORS_ORIGINS`
- Support iOS app origin: `capacitor://localhost`
- Support web domains
- Allow credentials for session-based auth

## 2. Web Module Configuration

### Update AuthContext.tsx

Replace the placeholder URL in `web/src/contexts/AuthContext.tsx`:
```typescript
const API_BASE_URL = 'https://your-actual-lightsail-domain.com';
```

### Update Register.tsx

Replace the placeholder URL in `web/src/pages/Register.tsx`:
```typescript
const API_BASE_URL = 'https://your-actual-lightsail-domain.com';
```

## 3. iOS Module Configuration

### Update APIService.swift

Replace the base URL in `ios/HandReceipt/Services/APIService.swift`:
```swift
init(urlSession: URLSession = .shared, baseURLString: String = "https://your-actual-lightsail-domain.com/api") {
    // ...
}
```

### Update Info.plist

Replace the placeholder domain in `ios/HandReceipt/Info.plist`:
```xml
<key>your-actual-lightsail-domain.com</key>
<dict>
    <key>NSExceptionAllowsInsecureHTTPLoads</key>
    <false/>
    <key>NSIncludesSubdomains</key>
    <true/>
</dict>
```

## 4. Database Migration

Run the user table migration on your PostgreSQL database:

```bash
# Connect to PostgreSQL
sudo -u postgres psql -d handreceipt

# Run the migration
\i /path/to/sql/migrations/004_update_users_table.sql
```

## 5. SSL/HTTPS Setup (Recommended)

1. Install Certbot:
```bash
sudo apt update
sudo apt install certbot
```

2. Obtain SSL certificate:
```bash
sudo certbot certonly --standalone -d your-domain.com
```

3. Configure your reverse proxy (nginx/apache) to use the certificate.

## 6. Testing the Connection

### Test Backend Health

```bash
curl https://your-domain.com/api/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "handreceipt-api",
  "version": "1.0.0"
}
```

### Test Registration

```bash
curl -X POST https://your-domain.com/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "testuser",
    "email": "test@example.com",
    "password": "securepassword",
    "first_name": "Test",
    "last_name": "User",
    "rank": "CPT",
    "unit": "Test Unit"
  }'
```

## 7. Troubleshooting

### Common Issues

1. **CORS errors**: Check that your domain is in the `CORS_ORIGINS` environment variable
2. **Connection refused**: Ensure port 8080 (or your configured port) is open in Lightsail firewall
3. **SSL errors**: Verify certificate is properly installed and domain matches
4. **Database connection**: Check `DATABASE_URL` is correct and PostgreSQL is running

### View Logs

```bash
# Service logs
sudo journalctl -u handreceipt -f

# PostgreSQL logs
sudo tail -f /var/log/postgresql/postgresql-*.log
```

## Security Checklist

- [ ] Use HTTPS in production
- [ ] Set strong JWT_SECRET and SESSION_SECRET
- [ ] Restrict database access to localhost only
- [ ] Keep Lightsail firewall rules minimal
- [ ] Regularly update system packages
- [ ] Enable automatic backups for database
- [ ] Monitor logs for suspicious activity

## Next Steps

1. Update all placeholder URLs with your actual domain
2. Test registration and login flows
3. Configure monitoring and alerts
4. Set up automated backups
5. Document your specific configuration 