# Cleanup Candidates for HandReceipt Codebase

This document identifies files that can be deleted from the codebase. Files are categorized by priority and type.

## 🚨 CRITICAL - Security Issue

### Exposed API Key
- **`/backend/test-azure-ocr.sh`** - Contains exposed Azure API key on line 13
  - **Action Required**: Delete file immediately and rotate the Azure OCR API key

## 🗑️ HIGH PRIORITY - Safe to Delete

### 1. Build Artifacts and Generated Files
```
/backend/bin/                                    # Go build output
/web/dist/                                      # Web build output
/tsconfig.tsbuildinfo                           # TypeScript build info
/web/tsconfig.tsbuildinfo                       # TypeScript build info
/ios/HandReceipt.xcodeproj/project.xcworkspace/xcuserdata/  # iOS user state
```

### 2. Empty Backup Directories
```
/web/backup_20250620_144816/                    # Empty backup directory
/web/backup_20250620_144823/                    # Empty backup directory
```

### 3. Temporary Migration Scripts
```
/web/cleanup-duplicate-files.sh                 # TypeScript migration cleanup (completed)
/web/fix-remaining-any.sh                       # TypeScript 'any' type fixes (completed)
```

### 4. Planning Documents
```
/plan1.md                                       # Old planning document
/plan2.md                                       # Old planning document
/plan3.md                                       # Old planning document
/plan4.md                                       # Old planning document
```

## 📁 MEDIUM PRIORITY - Review Before Deleting

### 1. Duplicate Logo Files

**hr_logo1.png** duplicates:
```
/assets/hr_logo1.png                            # Keep this (source)
/web/public/hr_logo1.png                        # Delete (duplicate)
/web/src/assets/hr_logo1.png                    # Delete (duplicate)
```

**hr_logo4.png** duplicates:
```
/assets/hr_logo4.png                            # Keep this (source)
/ios/HandReceipt/Assets.xcassets/hr_logo4.png   # Delete (duplicate)
/ios/HandReceipt/hr_logo4.png                   # Delete (duplicate)
/web/public/hr_logo4.png                        # Delete (duplicate)
```

**hr_logo5.png** duplicates:
```
/assets/hr_logo5.png                            # Keep this (source)
/web/public/hr_logo5.png                        # Delete (duplicate)
/web/src/assets/hr_logo5.png                    # Delete (duplicate)
```

**hr_logo6.png** duplicates:
```
/assets/hr_logo6.png                            # Keep this (source)
/ios/HandReceipt/Assets.xcassets/hr_logo6.png   # Delete (duplicate)
/ios/HandReceipt/hr_logo6.png                   # Delete (duplicate)
```

**sampleDA2062.png** duplicates:
```
/assets/sampleDA2062.png                        # Keep this (source)
/ios/HandReceipt/Assets.xcassets/sampleDA2062.imageset/sampleDA2062.png  # Delete (duplicate)
```

### 2. Example/Template Files
```
/backend/dev.env.example                        # Example env file
/backend/configs/config.example.yaml            # Example config
```

### 3. One-Time Setup Scripts
```
/setup_postgres.sh                              # PostgreSQL setup
/verify-github-actions-setup.sh                 # GitHub Actions verification
/ios/generate_app_icons.sh                      # iOS icon generation
/ios/generate_app_icons_macos.sh               # macOS icon generation
/ios/generate_hr_logo6_icons.sh                 # Logo icon generation
/ios/clean_build.sh                             # iOS build cleanup
/backend/scripts/clean-build.sh                 # Backend build cleanup
```

### 4. Completed Migration Scripts
```
/backend/scripts/apply_email_migration.sh       # Email migration (contains hardcoded password!)
/backend/scripts/fix_users_email_migration.sql  # User email fix
/backend/scripts/create_documents_table.sql     # Documents table creation
/backend/scripts/postgres_schema_updates.sql    # Schema updates
/backend/deployments/azure/migrate-data.sh      # Azure data migration
```

### 5. Test Data Files
```
/backend/internal/publog/data/cage_addresses_sample.txt    # Sample data (17K lines)
/backend/internal/publog/data/part_numbers_sample.txt      # Sample data (2K lines)
/backend/internal/publog/data/sample_niins.txt             # Sample data (1K lines)
/backend/internal/publog/data/test_parts.txt               # Empty test file
/backend/internal/publog/data/part_numbers_key_fscs.txt    # Empty file
```

## 🤔 LOW PRIORITY - Consider Archiving

### 1. Implementation Documentation
```
/GITHUB-ACTIONS-SETUP.md                        # GitHub Actions setup guide
/SETUP-SSL-GUIDE.md                             # SSL setup guide
/LINTER_DIAGNOSIS_AND_FIX_PLAN.md               # Linter fix documentation
/FRONTEND_BACKEND_INTEGRATION_REPORT.md         # Integration report
/ios/DA2062_IMPLEMENTATION_COMPLETION.md        # iOS implementation notes
/ios/DA2062_IMPORT_ENHANCEMENT_SUMMARY.md       # iOS enhancement summary
/backend/DEPLOYMENT-GUIDE.md                    # Old AWS Lightsail guide
```

### 2. Test Files
```
/backend/tests/postman_collection.json          # Postman test collection
/backend/scripts/test-publog-integration.sh     # PubLog test script
/web/cypress/fixtures/                          # Cypress test fixtures (if not using Cypress)
```

### 3. Deployment Scripts
```
/backend/scripts/deploy-publog-data-manual.sh   # Manual deployment script
/backend/deployments/azure/setup-github-secrets.sh  # GitHub secrets setup
/backend/deployments/azure/fix-cors-now.txt     # Temporary CORS fix note
```

## 📊 Space Savings Summary

- **High Priority Deletions**: ~10MB+ (mostly from /web/dist/)
- **Logo Duplicates**: ~800KB
- **Sample Data**: ~2-3MB
- **Total Potential Savings**: ~15MB

## 🔧 Recommended Actions

1. **Immediate Actions**:
   - Delete `/backend/test-azure-ocr.sh` and rotate Azure API key
   - Remove all build artifacts (bin/, dist/, *.tsbuildinfo)
   - Remove empty backup directories

2. **Before Deleting Migration Scripts**:
   - Verify all migrations have been applied to production
   - Check that documents table exists
   - Confirm email column exists in users table

3. **Logo File Consolidation**:
   - Keep logos only in `/assets/` directory
   - Update build processes to copy logos to platform-specific locations
   - Remove all duplicate logo files

4. **Archive Instead of Delete**:
   - Create an `_archive/` directory for documentation you want to keep but not in active codebase
   - Move implementation guides and completed task documentation there

## ⚠️ DO NOT DELETE

- Active configuration files (config.yaml, config.production.yaml, etc.)
- Production data files:
  - `/backend/internal/publog/data/master_nsn_all.txt` (754K lines)
  - `/backend/internal/publog/data/unique_niins.txt` (612K lines)
- Source code files
- Active deployment scripts
- Docker configuration files
- CLAUDE.md and TODO.md