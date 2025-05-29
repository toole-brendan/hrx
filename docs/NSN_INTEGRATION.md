# NSN/LIN Integration Guide

## Overview

The HandReceipt system now includes National Stock Number (NSN) and Line Item Number (LIN) lookup functionality to help users accurately identify and catalog military equipment.

## Steps to Enable NSN/LIN Lookup

### 1. Subscribe to PUBLOG

- **Cost**: $200-300/year
- **Website**: https://www.dlis.dla.mil/publog/
- **What you get**: Monthly DVD updates with NSN data in CSV format

### 2. Set Up Database

Run the NSN catalog migration to create the necessary tables:

```bash
# Connect to your database and run the migration
psql "YOUR_DATABASE_URL" -f backend/migrations/003_nsn_catalog.sql
```

### 3. Configure NSN Service

Add NSN configuration to your `backend/configs/config.yaml`:

```yaml
nsn:
  cache_enabled: true
  cache_ttl: 24h
  bulk_batch_size: 1000
  timeout_seconds: 30
  rate_limit_rps: 10
  # Optional: External API settings
  # api_endpoint: "https://api.example.com/nsn"
  # api_key: "your-api-key"
```

### 4. Import PUBLOG Data

Once you receive your PUBLOG DVD, extract the CSV files and import them:

```bash
# Build the import tool
cd backend
go build -o import_publog scripts/import_publog.go

# Preview the import (dry run)
./import_publog -file path/to/publog.csv -dry-run

# Import the data
./import_publog -file path/to/publog.csv
```

### 5. Verify Installation

Start your backend server and test the NSN endpoints:

```bash
# Search for items
curl http://localhost:8080/api/nsn/search?q=hammer

# Lookup specific NSN
curl http://localhost:8080/api/nsn/5120001234567

# Lookup by LIN
curl http://localhost:8080/api/lin/H12345
```

## iOS App Usage

The NSN/LIN lookup is integrated into the manual property entry screen:

1. **Direct NSN Lookup**: Enter a 13-digit NSN and tap the magnifying glass
2. **Direct LIN Lookup**: Enter a 6-character LIN and tap the magnifying glass
3. **Search Database**: Tap "Search NSN Database" to search by item name, NSN, or part number

When an item is found, the app will automatically populate:
- Item name
- NSN/LIN
- Manufacturer information
- Part numbers
- Unit price (if available)

## API Endpoints

### NSN Lookup
```
GET /api/nsn/:nsn
```

### LIN Lookup
```
GET /api/lin/:lin
```

### Search NSN Database
```
GET /api/nsn/search?q=query&limit=20
```

### Bulk NSN Lookup
```
POST /api/nsn/bulk
Body: { "nsns": ["NSN1", "NSN2", ...] }
```

### Admin Endpoints

#### Import CSV Data
```
POST /api/nsn/import (requires admin role)
Form data: file (CSV file)
```

#### Get Statistics
```
GET /api/nsn/stats
```

## Database Schema

The NSN integration adds the following tables:

- `nsn_items`: Main NSN catalog data
- `nsn_parts`: Part numbers and manufacturers
- `lin_items`: LIN reference data
- `cage_codes`: Manufacturer/supplier codes
- `nsn_synonyms`: Alternative names for items
- `catalog_updates`: Track data imports

## Maintenance

### Monthly Updates

When you receive monthly PUBLOG updates:

1. Extract the CSV files from the DVD
2. Run the import script with the new data
3. The system will automatically update existing records and add new ones

### Database Optimization

The system includes full-text search indexes for fast lookups. To maintain performance:

```sql
-- Rebuild search indexes monthly
REINDEX INDEX idx_nsn_item_name_gin;
REINDEX INDEX idx_nsn_description_gin;

-- Update statistics
ANALYZE nsn_items;
```

## Troubleshooting

### Common Issues

1. **Import fails with encoding errors**
   - Ensure CSV files are in UTF-8 encoding
   - Use `iconv` to convert if needed: `iconv -f ISO-8859-1 -t UTF-8 input.csv > output.csv`

2. **Search performance is slow**
   - Check that indexes exist: `\di *nsn*` in psql
   - Run `VACUUM ANALYZE nsn_items;`

3. **NSN not found but should exist**
   - Check NSN format (should be 13 digits, no dashes in database)
   - Verify data was imported: `SELECT COUNT(*) FROM nsn_items;`

## Security Considerations

- NSN data is not classified but may be sensitive
- Ensure proper access controls on admin endpoints
- Regular backups of NSN data are recommended
- Consider data retention policies for old catalog data 