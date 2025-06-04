-- Migration: Remove username column from users table
-- This migration removes the username field entirely, making email the sole login identifier

-- Drop the username column and its associated index
ALTER TABLE users DROP COLUMN IF EXISTS username;

-- Ensure email column is NOT NULL and has unique constraint
ALTER TABLE users ALTER COLUMN email SET NOT NULL;

-- Create unique index on email if it doesn't exist
CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Drop the old username index if it exists
DROP INDEX IF EXISTS idx_users_username;

-- Update any existing users without email to have a placeholder email
-- This is a safety measure for existing data
UPDATE users 
SET email = CONCAT(LOWER(REPLACE(name, ' ', '.')), '@handreceipt.local')
WHERE email IS NULL OR email = ''; 