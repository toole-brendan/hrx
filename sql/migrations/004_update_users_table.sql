-- Migration: Update users table for API compatibility
-- Add missing columns for registration

-- Add email column
ALTER TABLE users ADD COLUMN IF NOT EXISTS email VARCHAR(255) UNIQUE;

-- Add first_name and last_name columns
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_name VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_name VARCHAR(100);

-- Add unit column
ALTER TABLE users ADD COLUMN IF NOT EXISTS unit VARCHAR(200);

-- Add role column with default value
ALTER TABLE users ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'user';

-- Drop existing name column if it exists
ALTER TABLE users DROP COLUMN IF EXISTS name;

-- Add name column as a generated column from first_name and last_name
ALTER TABLE users ADD COLUMN name VARCHAR(200) GENERATED ALWAYS AS (
    CASE 
        WHEN first_name IS NOT NULL AND last_name IS NOT NULL THEN first_name || ' ' || last_name
        WHEN first_name IS NOT NULL THEN first_name
        WHEN last_name IS NOT NULL THEN last_name
        ELSE ''
    END
) STORED;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_name ON users(name);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- Add comment for documentation
COMMENT ON COLUMN users.name IS 'Combined full name for API compatibility';
COMMENT ON COLUMN users.email IS 'User email address for authentication';
COMMENT ON COLUMN users.first_name IS 'User first name';
COMMENT ON COLUMN users.last_name IS 'User last name';
COMMENT ON COLUMN users.unit IS 'Military unit assignment';
COMMENT ON COLUMN users.role IS 'User role in the system (user, admin, etc.)'; 