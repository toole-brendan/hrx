# PUB LOG Integration Setup Checklist

Use this checklist to ensure your PUB LOG integration is properly set up and functioning.

## Prerequisites

- [ ] Go 1.19+ installed
- [ ] PostgreSQL database running
- [ ] PUB LOG data files extracted from DVD

## Data Setup

- [ ] Create data directory: `mkdir -p backend/internal/publog/data`
- [ ] Copy `master_nsn_all.txt` to `backend/internal/publog/data/`
- [ ] Copy `part_numbers_sample.txt` to `backend/internal/publog/data/`
- [ ] Copy `cage_addresses_sample.txt` to `backend/internal/publog/data/`
- [ ] Verify files are pipe-delimited with headers

## Configuration

- [ ] Copy config example: `cp backend/configs/config.example.yaml backend/configs/config.yaml`
- [ ] Update database connection settings in `config.yaml`
- [ ] Ensure `nsn.publog_data_dir` is set to `"internal/publog"`
- [ ] Set `nsn.cache_enabled` to `true`

## Build & Run

- [ ] Install dependencies: `cd backend && go mod download`
- [ ] Run database migrations: `go run cmd/migrate/main.go up`
- [ ] Start server: `go run cmd/server/main.go`
- [ ] Check logs for "PUB LOG data loaded successfully"

## Verification

- [ ] Test PUB LOG CLI: `./bin/publog-test -data internal/publog`
- [ ] Run integration tests: `./scripts/test-publog-integration.sh`
- [ ] Try universal search: `curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/nsn/universal-search?q=camera`
- [ ] Verify NSN lookup: `curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:8080/api/nsn/5820-01-546-5288`

## Frontend Integration

- [ ] Update frontend NSN service to use `/api/nsn/universal-search`
- [ ] Add NSN search component to property forms
- [ ] Test NSN autocomplete functionality
- [ ] Verify NSN data populates item details

## Performance Check

- [ ] Monitor server memory usage (should be ~500MB with full dataset)
- [ ] Test search response times (<50ms for most queries)
- [ ] Verify cache is working: check `/api/nsn/cache/stats`

## Troubleshooting

If any step fails:

1. Check server logs for detailed error messages
2. Verify file permissions: `ls -la backend/internal/publog/data/`
3. Test data loading: `go run cmd/publog-test/main.go -data internal/publog -verbose`
4. See `backend/docs/PUBLOG_INTEGRATION.md` for detailed troubleshooting

## Success Indicators

✅ Server starts without PUB LOG errors
✅ Can search by NSN, part number, or item name
✅ Results include manufacturer and part number data
✅ Search responses are fast (<100ms)
✅ Frontend can display NSN search results

## Next Steps

Once everything is working:

1. Import full PUB LOG dataset (if available)
2. Set up automated data updates
3. Add NSN images/photos
4. Implement offline sync for mobile app
5. Create NSN bookmark/favorites feature 