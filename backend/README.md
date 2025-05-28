# HandReceipt Go Backend

This is the Go backend for the HandReceipt application, providing API services for inventory and supply chain management with AWS QLDB integration for immutable record-keeping.

## Features

- RESTful API for users, inventory items, transfers, and activities
- Secure authentication with JWT
- PostgreSQL database for storing relational data
- AWS QLDB integration for immutable ledger records of critical operations
- Docker and Docker Compose configuration for easy development and deployment

## Prerequisites

- Go 1.21 or later
- PostgreSQL 14 or later
- Docker and Docker Compose (optional, for containerized setup)
- AWS Account with QLDB service access
- AWS CLI configured with appropriate credentials

## Local Development Setup

### Option 1: Direct Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/toole-brendan/handreceipt_def_functional.git
   cd handreceipt_def_functional/server
   ```

2. **Install dependencies**

   ```bash
   go mod download
   ```

3. **Create and configure the database**

   ```bash
   # Create a PostgreSQL database named 'handreceipt'
   createdb handreceipt
   ```

4. **Configure environment variables**

   Create a `.env` file in the server directory with the following variables:

   ```
   HANDRECEIPT_DATABASE_HOST=localhost
   HANDRECEIPT_DATABASE_PORT=5432
   HANDRECEIPT_DATABASE_USER=your_db_user
   HANDRECEIPT_DATABASE_PASSWORD=your_db_password
   HANDRECEIPT_DATABASE_NAME=handreceipt
   HANDRECEIPT_SERVER_PORT=5000
   HANDRECEIPT_AUTH_JWT_SECRET=your_jwt_secret_key
   
   # AWS credentials for QLDB
   AWS_ACCESS_KEY_ID=your_aws_access_key
   AWS_SECRET_ACCESS_KEY=your_aws_secret_key
   AWS_REGION=your_aws_region
   ```

5. **Run the application**

   ```bash
   go run cmd/server/main.go
   ```

   The API should now be running at http://localhost:5000

### Option 2: Docker Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/toole-brendan/handreceipt_def_functional.git
   cd handreceipt_def_functional/server
   ```

2. **Configure AWS credentials**

   Ensure your AWS credentials are available as environment variables or in your AWS CLI configuration.

3. **Start with Docker Compose**

   ```bash
   docker-compose up -d
   ```

   This will:
   - Start a PostgreSQL database
   - Build and start the Go API server
   - Configure all necessary environment variables

   The API should now be running at http://localhost:5000

## API Endpoints

### Authentication

- **POST /api/auth/login** - User login
- **POST /api/auth/register** - User registration
- **GET /api/me** - Get current authenticated user

### Inventory

- **GET /api/inventory** - Get all inventory items
- **GET /api/inventory/:id** - Get a specific inventory item
- **POST /api/inventory** - Create a new inventory item
- **PATCH /api/inventory/:id/status** - Update an inventory item's status
- **GET /api/inventory/user/:userId** - Get inventory items assigned to a specific user
- **GET /api/inventory/history/:serialNumber** - Get the history of an inventory item from QLDB

## Project Structure

```
server/
├── cmd/
│   └── server/          # Main entry point
├── configs/             # Configuration files
├── internal/
│   ├── api/             # API handlers and middleware
│   │   ├── handlers/    # Request handlers
│   │   ├── middleware/  # Middleware functions
│   │   └── routes/      # Route definitions
│   ├── domain/          # Business domain models
│   ├── ledger/          # AWS QLDB integration
│   └── platform/        # Infrastructure components
│       └── database/    # Database connection and models
├── Dockerfile           # Docker configuration
├── docker-compose.yml   # Docker Compose configuration
└── go.mod               # Go module definition
```

## Architecture Overview

1. **API Layer** - Handles HTTP requests using the Gin framework
2. **Domain Layer** - Contains business logic and domain models
3. **Platform Layer** - Handles infrastructure concerns like database access
4. **Ledger Layer** - Interacts with AWS QLDB for immutable record-keeping

The application follows a clean architecture approach, separating concerns between layers.

## AWS QLDB Integration

The application uses AWS QLDB to store immutable records of critical operations:

- Item creations
- Transfer events
- Status changes
- Verification events
- Correction events

Each event is recorded with a timestamp, user information, and relevant details, creating an auditable trail of all important actions in the system.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License. 