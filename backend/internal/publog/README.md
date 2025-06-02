# PUB LOG Integration

This package provides integration with PUB LOG (Publication Logistics) data for military equipment lookups.

## Data Format

The publog service supports two data formats:

### 1. Extracted Pipe-Delimited Format (Recommended)
- `master_nsn_all.txt` - Master NSN file with all items
- `part_numbers_sample.txt` - Part number cross-references
- `cage_addresses_sample.txt` - CAGE (manufacturer) addresses

File format:
```
INC|ITEM_NAME|FSC|END_ITEM_NAME|CANCELLED_NIIN|SOS|NIIN
00091|CAMERA,TELEVISION|5820|0205848-310 (55910), VIXS, SHIPBOARD||SMS|015465288
```

### 2. Original TAB Format
- `V_FLIS_NSN.TAB` - NSN items
- `V_FLIS_PART.TAB` - Part numbers
- `V_CAGE_ADDRESS.TAB` - CAGE addresses
- `V_MOE_RULE.TAB` - Method of Evaluation rules
- `V_FLIS_MANAGEMENT.TAB` - Management data

## NSN Format

NSNs are formatted as: `XXXX-XX-XXX-XXXX`
- First 4 digits: Federal Supply Class (FSC)
- Next 2 digits: Federal Supply Group (FSG) 
- Next 3 digits: Country code
- Last 4 digits: Item number

Example: `5820-01-234-5678`

## Usage

### Loading Data

```go
import "github.com/toole-brendan/handreceipt-go/internal/publog"

// Create service
service := publog.NewService()

// Load data (automatically detects format)
err := service.LoadDataFromDirectory("path/to/publog/data")
if err != nil {
    log.Fatal(err)
}
```

### Searching

```go
// Search by NSN
result, err := service.SearchNSN("5820-01-234-5678")

// Search by part number
results, err := service.SearchPartNumber("12345")

// Search by item name
results, err := service.SearchByName("radio antenna")

// Universal search (tries NSN, then part number, then name)
results, err := service.Search("5820-01-234-5678")
```

### Integration with NSN Service

The NSN service automatically uses publog data when available:

```go
// In config.yaml
nsn:
  publog_data_dir: "internal/publog"

// The NSN service will automatically load publog data on initialization
```

## Testing

Run the test CLI:
```bash
go run cmd/publog-test/main.go -data internal/publog
```

## Data Statistics

After loading the extracted data:
- NSN Items: 560,520+ items
- Part Numbers: 1,983 (sample)
- CAGE Addresses: 17,353 (sample)

All items have meaningful names (filtered out "NO ITEM NAME AVAILABLE"). 