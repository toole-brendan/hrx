# HandReceipt Database Migration Guide

## Overview
This guide provides step-by-step instructions for migrating your HandReceipt database to align with the latest codebase changes.

## Pre-Migration Checklist

1. **Backup your database**
   ```bash
   pg_dump -U your_user -d handreceipt > handreceipt_backup_$(date +%Y%m%d_%H%M%S).sql
   ```

2. **Check current migration status**
   ```sql
   -- Connect to your database
   psql -U your_user -d handreceipt
   
   -- Check if migrations table exists
   SELECT * FROM schema_migrations ORDER BY version;
   ```

## Migration Files Analysis

### ✅ Apply These Migrations

1. **001_initial_schema.up.sql** - Core tables foundation
2. **003_nsn_catalog.sql** - NSN catalog structure (will be replaced by nsn_records)
3. **004_update_users_table.sql** - Adds military-specific fields
4. **006_transfer_system_refactor_phase1.sql** - User connections for Venmo-style transfers
5. **007_transfer_offers_system.sql** - Multi-recipient offer functionality
6. **008_complete_schema_alignment.sql** - NEW - Fixes all discrepancies

### ❌ Skip These Migrations

1. **002_add_qr_codes_table.sql** - QR functionality has been removed
2. **005_schema_reconciliation.sql** - May conflict with current schema, review carefully

## Step-by-Step Migration Instructions

### Option 1: Using migrate CLI Tool

```bash
# Install migrate tool if not already installed
brew install golang-migrate

# Set database URL
export DATABASE_URL="postgresql://user:password@localhost:5432/handreceipt?sslmode=disable"

# Apply migrations selectively
cd /path/to/handreceipt

# Apply initial schema (if not already applied)
migrate -path sql/migrations -database "$DATABASE_URL" goto 1

# Skip 002 (QR codes) and apply 003
migrate -path sql/migrations -database "$DATABASE_URL" goto 3

# Apply 004
migrate -path sql/migrations -database "$DATABASE_URL" goto 4

# Skip 005 and apply 006
migrate -path sql/migrations -database "$DATABASE_URL" goto 6

# Apply 007
migrate -path sql/migrations -database "$DATABASE_URL" goto 7

# Apply new alignment migration
migrate -path sql/migrations -database "$DATABASE_URL" up
```

### Option 2: Manual SQL Execution

```bash
# Connect to database
psql -U your_user -d handreceipt

# Check current state
\dt

# Apply migrations manually
\i sql/migrations/001_initial_schema.up.sql
-- Skip 002_add_qr_codes_table.sql
\i sql/migrations/003_nsn_catalog.sql
\i sql/migrations/004_update_users_table.sql
-- Review 005 carefully before applying
\i sql/migrations/006_transfer_system_refactor_phase1.sql
\i sql/migrations/007_transfer_offers_system.sql
\i sql/migrations/008_complete_schema_alignment.sql

# Verify schema
\i sql/verify_schema.sql
```

### Option 3: Fresh Database Setup

If starting fresh or having conflicts:

```bash
# Create new database
createdb handreceipt_new

# Connect to new database
psql -U your_user -d handreceipt_new

# Run migrations in correct order
\i sql/migrations/001_initial_schema.up.sql
\i sql/migrations/003_nsn_catalog.sql
\i sql/migrations/004_update_users_table.sql
\i sql/migrations/006_transfer_system_refactor_phase1.sql
\i sql/migrations/007_transfer_offers_system.sql
\i sql/migrations/008_complete_schema_alignment.sql

# Load seed data
\i sql/seed_nsn_records.sql
\i sql/corrected_seed_data.sql
```

## Post-Migration Steps

### 1. Verify Schema Integrity
```bash
psql -U your_user -d handreceipt < sql/verify_schema.sql
```

### 2. Load Development Data (Optional)
```bash
# Only for development environments
psql -U your_user -d handreceipt < sql/dev_seed_connections.sql
psql -U your_user -d handreceipt < sql/dev_seed_da2062.sql
```

### 3. Update Application Configuration

Update your backend configuration to ensure:
- Remove any QR code related endpoints
- Add DA2062 import endpoints
- Update transfer logic to use serial numbers

### 4. Test Critical Functions

```sql
-- Test user connections
SELECT * FROM user_friends_view LIMIT 5;

-- Test transfer offers
SELECT * FROM user_active_offers_view LIMIT 5;

-- Test DA2062 imports
SELECT * FROM da2062_import_status_view;

-- Test pending serial requests
SELECT * FROM pending_serial_requests_view;
```

## Troubleshooting

### Common Issues

1. **Migration 005 conflicts**
   - Review the migration file first
   - Comment out conflicting sections
   - Apply manually with modifications

2. **Foreign key violations**
   - Run data cleanup queries from migration 008
   - Check for orphaned records

3. **View creation fails**
   - Ensure all dependent tables exist
   - Check column names match

### Rollback Instructions

If you need to rollback:

```bash
# Using migrate tool
migrate -path sql/migrations -database "$DATABASE_URL" down 1

# Or restore from backup
psql -U your_user -d handreceipt < handreceipt_backup_YYYYMMDD_HHMMSS.sql
```

## Backend Code Updates Required

After migration, update these Go files:

1. **Remove QR Code Models**
   - Delete `models/qr_code.go`
   - Remove QR endpoints from `routes/`

2. **Add New Models**
   - Create `models/user_connection.go`
   - Create `models/transfer_offer.go`
   - Create `models/da2062_import.go`

3. **Update Transfer Logic**
   - Modify `services/transfer_service.go` to use serial numbers
   - Add friend network checks

## Final Checklist

- [ ] Database backed up
- [ ] Migrations applied successfully
- [ ] Schema verification passed
- [ ] Development data loaded (if needed)
- [ ] Backend code updated
- [ ] Application tested

## Support

If you encounter issues:
1. Check migration logs
2. Run verification script
3. Review error messages
4. Restore from backup if needed 