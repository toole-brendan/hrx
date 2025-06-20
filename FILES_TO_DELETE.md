# Files to Delete from HandReceipt Project

This document lists all files that should be deleted to clean up the codebase. These files are either outdated, temporary, or no longer needed.

## Outdated Documentation Files
```
/geo1.md
/geo2.md
/geo3.md
/geo4.md
/geo5.md
/styling1.md
/styling2.md
/styling3.md
/styling4.md
/styling5.md
/styling6.md
/styling7.md
/styling8.md
/webstyling.md
/WEB_TO_IOS_IMPLEMENTATION_PLAN.md
/IMPLEMENTATION_SUMMARY.md
/DA2062_FIX_VERIFICATION.md
/PROPERTY_BOOK_BLANK_PAGE_FIX.md
/immudb-connection-troubleshooting.md
```

## Temporary Fix and Debug Scripts
```
/fix_session.sh
/fix-lightsail-database.sh
/fix-immudb-connection.sh
/fix-nginx-cors.sh
/fix-registration-complete.sh
/quick-fix-registration.sh
/check-registration-issue.sh
/diagnose-login-issue.sh
/diagnose-azure-login-issue.sh
/test-azure-login.sh
/debug-backend-azure.sh
/emergency-backend-fix.sh
/check-migration-status.sh
/test-api-connection.sh
/test-ssh.sh
/test-azure-ocr.sh
/backend/test-azure-ocr.sh
/update-cors-ports.sh
```

## Old Deployment and Migration Scripts
```
/apply-migration-lightsail.sh
/apply-migration-on-lightsail.sh
/run-property-migration.sh
/property-rename-files.sh
/property-search-replace.sh
/setup-ssl-lightsail.sh
/run_seed_production.sh
```

## Build Artifacts and Archives
```
/backend/deployment.tar.gz
/backend/deployment-clean.tar.gz
/backend/deployments/lightsail/handreceipt-deploy.tar.gz
/backend/handreceipt-backend
/backend/main
/backend/server
/backend/bin/
/cookies.txt
```

## AWS/Lightsail Specific Files (No Longer Needed)
```
/backend/deployments/azure/fix-cors-now.txt
/backend/deployments/lightsail/fix-authorized-keys.txt
/backend/deployments/lightsail/fix-docker-network.sh
/backend/deployments/lightsail/fix-docker-network-v2.sh
/backend/deployments/lightsail/fix-env-vars.sh
/backend/deployments/lightsail/fix-ssh-access.sh
/backend/deployments/lightsail/quick-fix-commands.sh
/backend/deployments/lightsail/diagnose-ssh.sh
/backend/deployments/lightsail/test-ssh.sh
/backend/deployments/lightsail/ssl/cert.pem
/backend/deployments/lightsail/ssl/key.pem
```

## Obsolete Backend Scripts
```
/backend/scripts/fix-deployment.sh
/backend/scripts/fix-nginx-ssl.sh
/backend/scripts/fix-obsolete-files.sh
/backend/scripts/fix-database-views.sh
/backend/scripts/fix-da2062-documents-table.sh
/backend/scripts/fix-azure-da2062-documents.sh
/backend/scripts/azure_ledger_schema.sql.backup
```

## Python Utility Scripts
```
/decompress_publog.py
/publog_decompress.py
/ios/add_black_background.py
```

## OS-Generated Files
```
# Find and delete all .DS_Store files:
find . -name ".DS_Store" -type f -delete
```

## Node Modules (Should be in .gitignore)
```
/node_modules/
/sql/node_modules/
/web/node_modules/
```

## Build Output
```
/web/dist/
```

## Commands to Delete Files

You can use these commands to delete the files:

```bash
# First, make sure you have a backup or commit your current state
git status
git add -A
git commit -m "Backup before cleanup"

# Delete documentation files
rm -f geo*.md styling*.md webstyling.md WEB_TO_IOS_IMPLEMENTATION_PLAN.md IMPLEMENTATION_SUMMARY.md DA2062_FIX_VERIFICATION.md PROPERTY_BOOK_BLANK_PAGE_FIX.md immudb-connection-troubleshooting.md

# Delete fix scripts
rm -f fix*.sh quick-fix*.sh check*.sh diagnose*.sh test*.sh debug*.sh emergency*.sh update-cors-ports.sh

# Delete old deployment scripts
rm -f apply-migration*.sh run-property-migration.sh property-*.sh setup-ssl-lightsail.sh run_seed_production.sh

# Delete build artifacts
rm -f backend/*.tar.gz backend/handreceipt-backend backend/main backend/server cookies.txt
rm -rf backend/bin/

# Delete Lightsail deployment files
rm -rf backend/deployments/lightsail/

# Delete obsolete backend scripts
rm -f backend/scripts/fix-*.sh backend/scripts/*.backup

# Delete Python scripts
rm -f decompress_publog.py publog_decompress.py ios/add_black_background.py

# Delete all .DS_Store files
find . -name ".DS_Store" -type f -delete

# Remove node_modules (if accidentally committed)
rm -rf node_modules/ sql/node_modules/ web/node_modules/

# Remove build output
rm -rf web/dist/
```

## Update .gitignore

After deleting these files, make sure your `.gitignore` includes:

```
# OS files
.DS_Store

# Build artifacts
*.tar.gz
/backend/bin/
/backend/handreceipt-backend
/backend/main
/backend/server
/web/dist/

# Dependencies
node_modules/

# Environment and secrets
.env
*.pem
*.key

# Temporary files
*.tmp
*.log
cookies.txt
```