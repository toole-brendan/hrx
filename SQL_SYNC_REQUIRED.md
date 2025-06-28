# SQL Schema Synchronization Required

## Issue Discovered

The DA 2062 fields have already been added to the database via migration `0015_add_da2062_fields.sql`, but the Drizzle ORM schema file is out of sync.

## Current State

### Database Has (via migration 0015):
- `unit_of_issue` column on properties table
- `condition_code` column on properties table  
- `category` column on properties table
- `manufacturer` column on properties table
- `part_number` column on properties table
- `security_classification` column on properties table
- `unit_of_issue_codes` reference table
- `property_categories` reference table
- `property_condition_history` table

### Drizzle Schema Missing:
All of the above fields and tables are missing from `/sql/schema.ts`

## Action Required

### Option 1: Update Drizzle Schema (Recommended)

Add to the properties table in `schema.ts`:

```typescript
export const properties = pgTable("properties", {
  // ... existing fields ...
  
  // DA 2062 fields (missing from schema)
  unitOfIssue: varchar("unit_of_issue", { length: 10 }).default('EA'),
  conditionCode: varchar("condition_code", { length: 10 }).default('A'),
  category: varchar("category", { length: 50 }),
  manufacturer: varchar("manufacturer", { length: 100 }),
  partNumber: varchar("part_number", { length: 50 }),
  securityClassification: varchar("security_classification", { length: 10 }).default('U'),
});

// Add new reference tables
export const unitOfIssueCodes = pgTable("unit_of_issue_codes", {
  code: varchar("code", { length: 10 }).primaryKey(),
  description: varchar("description", { length: 100 }).notNull(),
  category: varchar("category", { length: 50 }),
  sortOrder: integer("sort_order").default(0),
});

export const propertyCategories = pgTable("property_categories", {
  code: varchar("code", { length: 50 }).primaryKey(),
  name: varchar("name", { length: 100 }).notNull(),
  description: text("description"),
  isSensitive: boolean("is_sensitive").default(false),
  defaultSecurityClass: varchar("default_security_class", { length: 10 }).default('U'),
  sortOrder: integer("sort_order").default(0),
});

export const propertyConditionHistory = pgTable("property_condition_history", {
  id: serial("id").primaryKey(),
  propertyId: integer("property_id").notNull().references(() => properties.id, { onDelete: "cascade" }),
  previousCondition: varchar("previous_condition", { length: 10 }),
  newCondition: varchar("new_condition", { length: 10 }).notNull(),
  changedBy: integer("changed_by").references(() => users.id),
  changedAt: timestamp("changed_at").defaultNow(),
  reason: varchar("reason", { length: 255 }),
  notes: text("notes"),
});
```

### Option 2: Verify Database State First

Before making changes, verify what's actually in the database:

```bash
# Check if the columns exist
psql -U postgres -d handreceipt -c "\d properties"

# Check if the reference tables exist  
psql -U postgres -d handreceipt -c "\dt *unit_of_issue*"
psql -U postgres -d handreceipt -c "\dt *property_categories*"
```

### Option 3: Full Regeneration

If many migrations are out of sync with Drizzle:

```bash
# Pull schema from database
npx drizzle-kit introspect:pg

# This will generate a new schema based on actual database
```

## Why This Matters

1. **Type Safety**: Without correct Drizzle schema, TypeScript won't know about these fields
2. **Queries**: Drizzle queries won't be able to access the DA 2062 fields
3. **Migrations**: Future Drizzle migrations might conflict or fail

## Next Steps

1. Verify which approach your team prefers (manual update vs introspection)
2. Update the schema.ts file
3. Regenerate TypeScript types
4. Update backend models to use these fields
5. Test that queries work correctly

## Note on Implementation Plan

The implementation plan I created (`DA2062_IMPLEMENTATION_PLAN.md`) is still valid for:
- Backend model updates
- Frontend changes
- UX improvements

However, skip the database migration step since it's already done.