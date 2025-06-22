# HandReceipt Go Backend

This is the Go backend for the HandReceipt application, providing API services for military property accountability and supply chain management with Azure SQL Database ledger tables for immutable record-keeping.

## Features

- RESTful API for users, inventory items, transfers, and activities
- Secure authentication with JWT and session management
- PostgreSQL database for storing relational data
- Azure SQL Database ledger tables for immutable audit trail of all transactions
- MinIO for S3-compatible document and photo storage
- Docker and Docker Compose configuration for easy development and deployment
- NSN (National Stock Number) lookup service integration

## Architecture

The backend uses a microservices architecture with the following components:

- **Backend API** (Go/Gin) - Main application server on port 8080
- **PostgreSQL** - Primary relational database for current state
- **Azure SQL Database** - Primary database with ledger tables for immutable audit trail
- **MinIO** - S3-compatible object storage for photos and documents
- **Nginx** - Reverse proxy with SSL termination

## Prerequisites

- Go 1.21 or later
- Docker and Docker Compose
- PostgreSQL 14 or later (for local development without Docker)

## Local Development Setup

### Option 1: Docker Setup (Recommended)

1. **Clone the repository**

   ```bash
   git clone https://github.com/toole-brendan/handreceipt.git
   cd handreceipt/backend
   ```

2. **Start with Docker Compose**

   ```bash
   docker-compose up -d
   ```

   This will start:
   - PostgreSQL database on port 5432
   - Azure SQL Database connection (via configuration)
   - MinIO on ports 9000 (API) and 9001 (console)
   - Go API server on port 8080
   - Nginx proxy on ports 80/443

   The API will be available at http://localhost:8080

### Option 2: Direct Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/toole-brendan/handreceipt.git
   cd handreceipt/backend
   ```

2. **Install dependencies**

   ```bash
   go mod download
   ```

3. **Set up services**

   You'll need to run PostgreSQL and MinIO locally or update the config to point to external instances. For Azure SQL Database, configure the connection string.

4. **Configure the application**

   Copy `configs/config.yaml` to `configs/config.local.yaml` and update with your local settings:

   ```yaml
   database:
     host: "localhost"
     port: 5432
     user: "your_db_user"
     password: "your_db_password"
     name: "handreceipt"
   
   azure_sql:
     connection_string: "your_azure_sql_connection_string"
     ledger_enabled: true
   
   minio:
     endpoint: "localhost:9000"
     access_key_id: "minioadmin"
     secret_access_key: "minioadmin"
     enabled: true
   ```

5. **Run the application**

   ```bash
   go run cmd/server/main.go
   ```

## Production Deployment

The application is deployed on AWS Lightsail with the following configuration:

- **Instance**: Ubuntu 20.04 LTS on Lightsail
- **Domain**: api.handreceipt.com (with SSL via Let's Encrypt)
- **Services**: All services run in Docker containers managed by docker-compose

### Deployment URLs

- **Production API**: https://api.handreceipt.com
- **Health Check**: https://api.handreceipt.com/health
- **Frontend**: https://handreceipt.com (S3 + CloudFront)

## API Endpoints

### Authentication

- **POST /api/auth/login** - User login
- **POST /api/auth/register** - User registration  
- **POST /api/auth/logout** - User logout
- **GET /api/auth/me** - Get current authenticated user

### Inventory Management

- **GET /api/inventory** - Get all inventory items
- **GET /api/inventory/:id** - Get a specific inventory item
- **POST /api/inventory** - Create a new inventory item
- **PATCH /api/inventory/:id/status** - Update inventory item status
- **POST /api/inventory/:id/verify** - Verify inventory item
- **POST /api/inventory/:id/qrcode** - Generate QR code for item
- **GET /api/inventory/:id/qrcodes** - Get QR codes for item
- **GET /api/inventory/user/:userId** - Get items by user
- **GET /api/inventory/serial/:serialNumber** - Get item by serial number
- **GET /api/inventory/history/:serialNumber** - Get item history from ledger tables

### Transfers

- **GET /api/transfers** - Get all transfers
- **POST /api/transfers** - Create transfer request
- **GET /api/transfers/:id** - Get specific transfer
- **PATCH /api/transfers/:id/status** - Update transfer status
- **GET /api/transfers/user/:userId** - Get transfers by user
- **POST /api/transfers/qr-initiate** - Initiate transfer via QR code

### Reference Data

- **GET /api/reference/types** - List property types
- **GET /api/reference/models** - List property models
- **GET /api/reference/models/nsn/:nsn** - Get model by NSN

### NSN Integration

- **GET /api/nsn/lookup/:nsn** - Look up item by NSN
- **GET /api/nsn/search** - Search NSN database
- **POST /api/nsn/bulk-lookup** - Bulk NSN lookup

### Photos

- **POST /api/photos/property/:propertyId** - Upload property photo
- **GET /api/photos/property/:propertyId/verify** - Verify photo hash
- **DELETE /api/photos/property/:propertyId** - Delete property photo

## Environment Variables

The application uses a hierarchical configuration system:

1. Default values in code
2. `configs/config.yaml` - Base configuration
3. `configs/config.production.yaml` - Production overrides  
4. Environment variables (highest priority)

Key environment variables:

```bash
# Database
HANDRECEIPT_DATABASE_HOST=postgres
HANDRECEIPT_DATABASE_PORT=5432
HANDRECEIPT_DATABASE_USER=handreceipt
HANDRECEIPT_DATABASE_PASSWORD=your_password
HANDRECEIPT_DATABASE_NAME=handreceipt

# Azure SQL Database
HANDRECEIPT_AZURE_SQL_CONNECTION_STRING=your_connection_string
HANDRECEIPT_AZURE_SQL_LEDGER_ENABLED=true

# MinIO
HANDRECEIPT_MINIO_ENDPOINT=minio:9000
HANDRECEIPT_MINIO_ACCESS_KEY_ID=your_access_key
HANDRECEIPT_MINIO_SECRET_ACCESS_KEY=your_secret_key
HANDRECEIPT_MINIO_ENABLED=true

# JWT
HANDRECEIPT_JWT_SECRET_KEY=your_jwt_secret
```

## Testing

Run tests with:

```bash
go test ./...
```

For integration tests that require services:

```bash
docker-compose -f docker-compose.test.yml up -d
go test ./... -tags=integration
```

## Monitoring

The application exposes metrics for Prometheus at:
- Azure SQL Database metrics: Available through Azure Monitor
- Application metrics: (coming soon)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is proprietary and confidential.
```
# Build fix for gofpdf dependency
