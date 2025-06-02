# PUB LOG Integration Guide

## Overview

This guide provides comprehensive instructions for integrating and using the PUB LOG (Publication Logistics) data within the Hand Receipt application. The integration enables searching for military equipment by NSN (National Stock Number), part numbers, and item names.

## Quick Start

### 1. Data File Setup

Place the following extracted data files in `backend/internal/publog/data/`:

- **master_nsn_all.txt** - 560,520+ NSN records (41MB)
- **part_numbers_sample.txt** - 1,983 part number records (92KB)
- **cage_addresses_sample.txt** - 17,353 CAGE records (2.1MB)

### 2. Configuration

Ensure your `config.yaml` includes:

```yaml
nsn:
  publog_data_dir: "internal/publog"
  cache_enabled: true
  cache_ttl: "24h"
```

### 3. Start the Server

```bash
cd backend
go run cmd/server/main.go
```

The server will automatically load PUB LOG data on startup.

## API Endpoints

### Universal Search

Search across NSN, part numbers, and item names:

```bash
GET /api/nsn/universal-search?q=camera&limit=20
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "nsn": "5820-01-546-5288",
      "nomenclature": "CAMERA,TELEVISION",
      "fsc": "58",
      "niin": "015465288",
      "unit_price": 0,
      "manufacturer": "VIXS SYSTEMS INC",
      "part_number": "0205848-310",
      "specifications": {
        "Supply Code": "SMS"
      },
      "last_updated": "2024-01-01T00:00:00Z"
    }
  ],
  "count": 15,
  "query": "camera"
}
```

### NSN Lookup

Look up a specific NSN:

```bash
GET /api/nsn/5820-01-546-5288
```

### Search by Name

Search items by name:

```bash
GET /api/nsn/search?q=radio+antenna&limit=50
```

### Bulk NSN Lookup

Look up multiple NSNs:

```bash
POST /api/nsn/bulk
Content-Type: application/json

{
  "nsns": ["5820-01-546-5288", "5820-01-234-5678"]
}
```

## Data Format

### NSN Format
- Format: `XXXX-XX-XXX-XXXX`
- Example: `5820-01-546-5288`
  - 5820: Federal Supply Class (FSC)
  - 01: Country Code
  - 546-5288: Item Identification

### LIN Format
- Format: 6 alphanumeric characters
- Example: `T12345`

## Testing

### Run Integration Tests

```bash
# Basic test
./scripts/test-publog-integration.sh

# With verbose output
VERBOSE=true ./scripts/test-publog-integration.sh

# Show sample data
SHOW_SAMPLE=true ./scripts/test-publog-integration.sh

# With custom auth token
AUTH_TOKEN="your-token-here" ./scripts/test-publog-integration.sh
```

### Test Individual Components

```bash
# Test PUB LOG loader directly
go run cmd/publog-test/main.go -data internal/publog

# Search examples:
# NSN: 5820-01-546-5288
# Part Number: 12003100
# Item Name: camera television
```

## Performance

### Search Performance
- NSN lookup: ~5-10ms (from memory)
- Universal search: ~20-50ms (depends on query complexity)
- Bulk lookup: ~100-200ms for 50 items

### Memory Usage
- ~500MB for full dataset (560K+ items)
- Indexed for fast searching
- In-memory cache with 24h TTL

## Troubleshooting

### Data Not Loading

1. Check file paths:
   ```bash
   ls -la backend/internal/publog/data/
   ```

2. Verify file format (pipe-delimited with headers):
   ```bash
   head -n 2 backend/internal/publog/data/master_nsn_all.txt
   ```

3. Check server logs:
   ```
   INFO[0001] Loading PUB LOG data directory=internal/publog
   INFO[0002] PUB LOG data loaded successfully nsn_items=560520 part_numbers=1983 cage_addresses=17353
   ```

### Search Not Working

1. Verify data is loaded:
   ```bash
   curl http://localhost:8080/api/nsn/stats
   ```

2. Check cache stats:
   ```bash
   curl http://localhost:8080/api/nsn/cache/stats
   ```

3. Try direct NSN lookup:
   ```bash
   curl http://localhost:8080/api/nsn/5820-01-546-5288
   ```

### Performance Issues

1. Enable caching in config:
   ```yaml
   nsn:
     cache_enabled: true
     cache_ttl: "24h"
   ```

2. Increase rate limits if needed:
   ```yaml
   nsn:
     rate_limit_rps: 100
   ```

3. Monitor memory usage:
   ```bash
   # Check process memory
   ps aux | grep server
   ```

## Advanced Usage

### Custom Data Import

Import additional NSN data via CSV:

```bash
POST /api/nsn/import
Content-Type: multipart/form-data

file: @custom_nsn_data.csv
```

CSV format:
```csv
nsn,lin,item_name,description,category,manufacturer,part_number
5820-01-234-5678,T12345,RADIO SET,Tactical radio system,Communications,HARRIS CORP,RF-7800
```

### Cache Management

Clear cache:
```bash
# This would need to be implemented
POST /api/nsn/cache/clear
```

Refresh data:
```bash
POST /api/nsn/refresh
```

## Integration with Frontend

### React/TypeScript Example

```typescript
// services/nsnService.ts
export interface NSNDetails {
  nsn: string;
  nomenclature: string;
  fsc: string;
  niin: string;
  unit_price: number;
  manufacturer?: string;
  part_number?: string;
  specifications?: Record<string, string>;
  last_updated: string;
}

export const nsnService = {
  async universalSearch(query: string, limit = 20): Promise<NSNDetails[]> {
    const response = await fetch(
      `/api/nsn/universal-search?q=${encodeURIComponent(query)}&limit=${limit}`,
      {
        headers: {
          'Authorization': `Bearer ${getAuthToken()}`
        }
      }
    );
    const data = await response.json();
    return data.data || [];
  },

  async lookupNSN(nsn: string): Promise<NSNDetails | null> {
    const response = await fetch(`/api/nsn/${nsn}`, {
      headers: {
        'Authorization': `Bearer ${getAuthToken()}`
      }
    });
    const data = await response.json();
    return data.success ? data.data : null;
  }
};
```

### Usage in Component

```typescript
// components/NSNSearch.tsx
import React, { useState } from 'react';
import { nsnService, NSNDetails } from '../services/nsnService';

export const NSNSearch: React.FC = () => {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<NSNDetails[]>([]);
  const [loading, setLoading] = useState(false);

  const handleSearch = async () => {
    if (!query.trim()) return;
    
    setLoading(true);
    try {
      const data = await nsnService.universalSearch(query);
      setResults(data);
    } catch (error) {
      console.error('Search failed:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <input
        type="text"
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Search by NSN, part number, or item name..."
      />
      <button onClick={handleSearch} disabled={loading}>
        {loading ? 'Searching...' : 'Search'}
      </button>
      
      {results.map((item) => (
        <div key={item.nsn}>
          <h3>{item.nomenclature}</h3>
          <p>NSN: {item.nsn}</p>
          {item.manufacturer && <p>Manufacturer: {item.manufacturer}</p>}
          {item.part_number && <p>Part Number: {item.part_number}</p>}
        </div>
      ))}
    </div>
  );
};
```

## Security Considerations

1. **Authentication Required**: All NSN endpoints require valid authentication
2. **Rate Limiting**: Default 10 requests per second per user
3. **Admin Operations**: Import and refresh operations require admin role
4. **Data Validation**: All inputs are validated and sanitized

## Future Enhancements

1. **Full PUB LOG Dataset**: Currently using sample data for part numbers and CAGE codes
2. **Real-time Updates**: Integrate with live DoD data feeds
3. **Image Support**: Link NSN items to product images
4. **Specification Details**: Enhanced technical specifications
5. **Export Functionality**: Export search results to CSV/Excel
6. **Offline Support**: Download data for offline use in mobile app 