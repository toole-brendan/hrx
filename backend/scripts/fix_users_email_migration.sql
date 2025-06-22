-- Fix users table to add email column and update schema to match domain model
-- This script handles the migration from username-based to email-based authentication

-- First, add the email column as nullable
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS email VARCHAR(255);

-- Generate email addresses from existing usernames if email is null
-- This creates placeholder emails that users can update later
UPDATE public.users
SET email = CONCAT(LOWER(username), '@handreceipt.local')
WHERE email IS NULL;

-- Now make the email column NOT NULL and add unique constraint
ALTER TABLE public.users
ALTER COLUMN email SET NOT NULL;

-- Add unique constraint on email if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'users_email_key'
    ) THEN
        ALTER TABLE public.users
        ADD CONSTRAINT users_email_key UNIQUE (email);
    END IF;
END $$;

-- Add missing columns to match the domain model
ALTER TABLE public.users
ADD COLUMN IF NOT EXISTS first_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS last_name VARCHAR(255),
ADD COLUMN IF NOT EXISTS password_hash VARCHAR(255),
ADD COLUMN IF NOT EXISTS unit VARCHAR(255),
ADD COLUMN IF NOT EXISTS phone VARCHAR(50),
ADD COLUMN IF NOT EXISTS dodid VARCHAR(50),
ADD COLUMN IF NOT EXISTS signature_url VARCHAR(512);

-- Migrate data from existing columns
UPDATE public.users
SET first_name = SPLIT_PART(name, ' ', 1),
    last_name = CASE 
        WHEN POSITION(' ' IN name) > 0 
        THEN SUBSTRING(name FROM POSITION(' ' IN name) + 1)
        ELSE ''
    END
WHERE first_name IS NULL;

-- Copy password to password_hash if needed
UPDATE public.users
SET password_hash = password
WHERE password_hash IS NULL AND password IS NOT NULL;

-- Add unique constraint on dodid if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'users_dodid_key'
    ) THEN
        ALTER TABLE public.users
        ADD CONSTRAINT users_dodid_key UNIQUE (dodid);
    END IF;
END $$;

-- Add trigger to update 'updated_at' for users table if it doesn't exist
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_users') THEN
    CREATE TRIGGER set_timestamp_users
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
  END IF;
END $$;

-- Optional: Drop the old 'name' column after verification
-- WARNING: Only uncomment this after verifying the migration worked correctly
-- ALTER TABLE public.users DROP COLUMN IF EXISTS name;