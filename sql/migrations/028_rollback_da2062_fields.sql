-- Rollback Migration: Remove DA 2062 fields
-- Run this script to rollback migration 028_add_da2062_fields.sql

-- Drop indexes first
DROP INDEX IF EXISTS idx_properties_category;
DROP INDEX IF EXISTS idx_properties_condition;
DROP INDEX IF EXISTS idx_properties_security;
DROP INDEX IF EXISTS idx_condition_history_property;
DROP INDEX IF EXISTS idx_condition_history_date;

-- Drop condition history table
DROP TABLE IF EXISTS property_condition_history;

-- Drop reference tables
DROP TABLE IF EXISTS property_categories;
DROP TABLE IF EXISTS unit_of_issue_codes;

-- Remove columns from properties table
ALTER TABLE properties 
DROP COLUMN IF EXISTS unit_of_issue,
DROP COLUMN IF EXISTS condition_code,
DROP COLUMN IF EXISTS category,
DROP COLUMN IF EXISTS manufacturer,
DROP COLUMN IF EXISTS part_number,
DROP COLUMN IF EXISTS security_classification;

-- Note: This will permanently delete any data stored in these columns
-- Ensure you have a backup before running this rollback