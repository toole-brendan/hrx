# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HandReceipt is a military-grade property accountability system for tracking equipment and property with immutable record-keeping. It consists of:
- Go backend API (Gin framework)
- React web frontend (TypeScript, Vite, Tailwind CSS)
- Native iOS app (SwiftUI)
- Native Android app (Kotlin, Jetpack Compose)
- PostgreSQL database with ImmuDB for immutable audit trails
- MinIO for S3-compatible object storage

## Essential Commands

### Backend Development
```bash
cd backend
./start-dev.sh              # Start Docker services + Go API server
go test ./...               # Run all tests
go build -o bin/server cmd/server/main.go  # Build server binary
```

### Web Frontend Development
```bash
cd web
npm run dev                 # Start dev server on port 5001
npm run build              # Production build
npm run check              # TypeScript type checking
```

### Database Management
```bash
# From root directory
npm run db:generate        # Generate migrations with Drizzle
npm run db:migrate         # Apply migrations
npm run db:studio          # Open Drizzle Studio UI

# For SQL migrations
cd sql && ./apply_migrations.sh
```

### Running Tests
```bash
# Backend
cd backend && go test ./...

# Interactive transfer tests
./run-transfer-tests.sh
```

## Architecture Overview

### Backend Structure
The Go backend follows a clean architecture pattern:
- `cmd/` - Entry points (server, worker, tools)
- `internal/api/` - HTTP handlers and routes
- `internal/domain/` - Core domain models
- `internal/services/` - Business logic services
- `internal/ledger/` - ImmuDB integration for immutable records
- `internal/publog/` - NSN (National Stock Number) integration

### Key Services
- **Auth Service**: JWT-based authentication with session management
- **Transfer Service**: Manages property transfers between users with approval workflow
- **Ledger Service**: Immutable audit trail using ImmuDB
- **PDF Service**: DA Form 2062 generation and export
- **OCR Service**: Document scanning and text extraction
- **QR Service**: QR code generation for items

### Frontend Architecture
- React with TypeScript and functional components
- Context API for state management (AuthContext, etc.)
- Tailwind CSS with shadcn/ui components
- API services in `src/services/` for backend communication
- Protected routes with authentication checks

### Database Schema
Main entities managed by Drizzle ORM:
- Users with authentication and profile data
- Items with serial numbers and NSN codes
- Transfers with approval workflow
- User connections for secure transfers
- Audit logs and immutable ledger entries

### API Patterns
- RESTful endpoints under `/api`
- JWT authentication required for most endpoints
- Standard CRUD operations plus specialized endpoints:
  - `/api/transfers` - Transfer management
  - `/api/qr/:id` - QR code generation
  - `/api/da2062` - Form generation
  - `/api/publog/nsn/:nsn` - NSN lookup

## Development Workflow

1. **Local Development Setup**:
   - Run `./start-dev.sh` in backend directory to start all services
   - Services available at:
     - API: http://localhost:8080
     - Web: http://localhost:5001
     - PostgreSQL: localhost:5432
     - MinIO Console: http://localhost:9001

2. **Making Changes**:
   - Backend: Changes auto-reload with Air
   - Frontend: Vite provides HMR (Hot Module Replacement)
   - Database: Use Drizzle for schema changes, then generate and apply migrations

3. **Testing**:
   - Write tests alongside code changes
   - Backend: Standard Go testing with `_test.go` files
   - Use `./run-transfer-tests.sh` for interactive testing

4. **Environment Configuration**:
   - Backend uses hierarchical config: defaults → config.yaml → env vars
   - Environment variables use `HANDRECEIPT_` prefix
   - Separate configs for development/production/Azure

## Important Considerations

- **Immutability**: All property records and transfers are recorded in ImmuDB for audit compliance
- **Security**: JWT authentication, user connections for transfers, role-based access
- **Military Standards**: Follows DA Form 2062 standards for hand receipts
- **NSN Integration**: Requires PUBLOG data files for equipment lookup
- **Offline Support**: iOS and Android apps designed for offline operation with sync