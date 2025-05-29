# HandReceipt Integration Tests

This directory contains integration tests for the HandReceipt application, covering the complete create-sync-transfer-approve flow.

## Test Structure

### Postman Collection (`postman_collection.json`)
- Complete API integration test covering:
  - User authentication
  - Property creation with NSN/LIN data
  - Transfer request creation
  - Transfer approval workflow
  - Ledger history verification

### Go Integration Tests (`integration_test.go`)
- Full end-to-end test suite using Go's testing framework
- Tests the complete property transfer lifecycle
- Validates immutable ledger entries

## Running Tests

### Prerequisites
1. Ensure PostgreSQL test database is running:
   ```bash
   docker run -d --name handreceipt-test-db \
     -e POSTGRES_USER=test \
     -e POSTGRES_PASSWORD=test \
     -e POSTGRES_DB=handreceipt_test \
     -p 5432:5432 \
     postgres:14
   ```

2. Ensure ImmuDB is running (optional for mock tests):
   ```bash
   docker run -d --name immudb \
     -p 3322:3322 \
     codenotary/immudb:latest
   ```

### Running Go Integration Tests
```bash
# From the backend directory
go test ./tests/... -v
```

### Running Postman Tests
1. Import `postman_collection.json` into Postman
2. Set environment variables:
   - `base_url`: http://localhost:8000/api
3. Run the collection

### Running with Newman (CLI)
```bash
# Install Newman
npm install -g newman

# Run tests
newman run postman_collection.json \
  --environment handreceipt-test.postman_environment.json
```

## Test Coverage

The integration tests validate:
- ✅ User authentication flow
- ✅ Property creation with immutable ledger entry
- ✅ Transfer request creation
- ✅ Transfer approval by receiving user
- ✅ Ownership verification after transfer
- ✅ Complete audit trail in ledger

## Mock Services

For CI/CD environments, the tests use mock implementations:
- `MockLedgerService`: In-memory ledger for testing
- `test_router.go`: Minimal API endpoints for testing

## Troubleshooting

### Database Connection Errors
- Ensure PostgreSQL is running on port 5432
- Check database credentials match test configuration
- Run migrations: `make migrate-test`

### Test Failures
- Check server logs for detailed error messages
- Ensure all services are running
- Verify test data is properly seeded 