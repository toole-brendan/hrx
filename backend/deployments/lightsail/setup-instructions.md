# Lightsail Backend Configuration

## 1. Update Backend Service Configuration

SSH into your Lightsail instance:
```bash
ssh -i your-key.pem ubuntu@your-lightsail-ip
```

Update the systemd service file:
```bash
sudo nano /etc/systemd/system/handreceipt.service
```

Add/update these environment variables:
```
Environment="DATABASE_URL=postgresql://user:password@localhost/handreceipt"
Environment="JWT_SECRET=your-secure-secret"
Environment="CORS_ORIGINS=https://your-web-domain.com"
Environment="SESSION_SECRET=your-session-secret"
```

Restart the service:
```bash
sudo systemctl daemon-reload
sudo systemctl restart handreceipt
sudo systemctl status handreceipt
```

## 2. Verify Service is Running

Check logs:
```bash
sudo journalctl -u handreceipt -n 50 -f
```

## 3. Configure Firewall

Ensure ports are open:
```bash
sudo ufw allow 8080/tcp
sudo ufw status
```

## 4. SSL Configuration

If using HTTPS (recommended):
```bash
sudo apt update
sudo apt install certbot
sudo certbot certonly --standalone -d your-domain.com
```

## 5. Environment Variables Reference

- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Secret key for JWT token signing
- `CORS_ORIGINS`: Comma-separated list of allowed origins
- `SESSION_SECRET`: Secret key for session management
- `HANDRECEIPT_SERVER_PORT`: Server port (default: 8080) 