-- Migration: Update user name fields from single Name to FirstName/LastName
-- This migration removes the 'name' field and adds 'first_name' and 'last_name' fields
-- Also updates 'password' field to 'password_hash' for consistency

-- Drop the old name column
ALTER TABLE users DROP COLUMN IF EXISTS name;

-- Rename password column to password_hash if it exists
ALTER TABLE users RENAME COLUMN password TO password_hash;

-- Add new first_name and last_name columns
ALTER TABLE users ADD COLUMN first_name VARCHAR(50) NOT NULL DEFAULT '';
ALTER TABLE users ADD COLUMN last_name VARCHAR(50) NOT NULL DEFAULT '';

-- Remove the default constraint after adding the columns
ALTER TABLE users ALTER COLUMN first_name DROP DEFAULT;
ALTER TABLE users ALTER COLUMN last_name DROP DEFAULT; 