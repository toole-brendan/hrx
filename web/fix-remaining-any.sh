#!/bin/bash

echo "=== Fixing remaining 'any' types ==="

# Fix error handlers that use 'any'
find src -type f \( -name "*.ts" -o -name "*.tsx" \) -exec sed -i.bak 's/catch (error: any)/catch (error)/g' {} \;
find src -type f \( -name "*.ts" -o -name "*.tsx" \) -exec sed -i.bak 's/onError: (error: any)/onError: (error: Error)/g' {} \;

# Fix React.Dispatch<any>
find src -type f \( -name "*.ts" -o -name "*.tsx" \) -exec sed -i.bak 's/React\.Dispatch<any>/React.Dispatch<PropertyBookAction>/g' {} \;

# Fix Promise<any> to Promise<unknown>
find src -type f \( -name "*.ts" -o -name "*.tsx" \) -exec sed -i.bak 's/Promise<any>/Promise<unknown>/g' {} \;

# Fix : any to : unknown for general cases
find src -type f \( -name "*.ts" -o -name "*.tsx" \) -exec sed -i.bak 's/: any\[\]/: unknown[]/g' {} \;
find src -type f \( -name "*.ts" -o -name "*.tsx" \) -exec sed -i.bak 's/: any /: unknown /g' {} \;

# Remove backup files
find src -name "*.bak" -delete

echo "Fixed common 'any' patterns"
echo ""
echo "Remaining 'any' types that need manual review:"
grep -r "any" src --include="*.ts" --include="*.tsx" | grep -v "node_modules" | grep -v "// @ts-ignore" | grep -v "Germany" | grep -v "company" || echo "No remaining 'any' types found!"