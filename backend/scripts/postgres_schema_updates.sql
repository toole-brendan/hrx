-- Create Schema if it doesn't exist (Optional, if you prefer a dedicated schema)
-- CREATE SCHEMA IF NOT EXISTS handreceipt;
-- SET search_path TO handreceipt, public; -- Adjust search path if using a dedicated schema

-- Create the property table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.property (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create the users table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    rank VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- 1. Modify the main Property table
--    Assuming a table named 'property' already exists.
--    If it doesn't exist, you'd use CREATE TABLE instead.
ALTER TABLE public.property
ADD COLUMN IF NOT EXISTS serial_number VARCHAR(255), -- Add serial number column if it doesn't exist
ADD COLUMN IF NOT EXISTS property_model_id INT, -- Foreign key to the new reference model table
ADD COLUMN IF NOT EXISTS current_status VARCHAR(100) DEFAULT 'Unknown' NOT NULL, -- Tracks current state (e.g., Operational, In Repair)
ADD COLUMN IF NOT EXISTS assigned_to_user_id INT NULL, -- Tracks current assigned user
ADD COLUMN IF NOT EXISTS last_verified_at TIMESTAMPTZ NULL, -- Timestamp of last sensitive item verification
ADD COLUMN IF NOT EXISTS last_maintenance_at TIMESTAMPTZ NULL, -- Timestamp of last maintenance
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL;

-- Add a unique index on serial_number for quick lookups
-- Only add if the column was just created or doesn't have an index
DO $$
BEGIN
   IF NOT EXISTS (
       SELECT 1
       FROM   pg_class c
       JOIN   pg_namespace n ON n.oid = c.relnamespace
       JOIN   pg_index i ON i.indexrelid = c.oid
       JOIN   pg_attribute a ON a.attrelid = i.indrelid
       WHERE  n.nspname = 'public' -- Schema
       AND    c.relname = 'idx_property_serial_number' -- Index name
   ) THEN
       CREATE UNIQUE INDEX idx_property_serial_number ON public.property (serial_number);
   END IF;
END;
$$;

-- Add foreign key constraint if property_model_id was just added
-- Assumes property_models table is created below
ALTER TABLE public.property
ADD CONSTRAINT fk_property_model
FOREIGN KEY (property_model_id)
REFERENCES public.property_models(id)
ON DELETE SET NULL; -- Or RESTRICT, depending on desired behavior

ALTER TABLE public.property
ADD CONSTRAINT fk_property_assigned_user
FOREIGN KEY (assigned_to_user_id)
REFERENCES public.users(id)
ON DELETE SET NULL; -- Or RESTRICT


-- 2. Reference Database Tables

-- Property Types (Broad Categories, e.g., Weapon, Communication, Vehicle)
CREATE TABLE IF NOT EXISTS public.property_types (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Property Models (Specific Models, e.g., M4 Carbine, AN/PRC-152, HMMWV M1151)
CREATE TABLE IF NOT EXISTS public.property_models (
    id SERIAL PRIMARY KEY,
    property_type_id INT NOT NULL REFERENCES public.property_types(id) ON DELETE RESTRICT,
    model_name VARCHAR(255) NOT NULL, -- e.g., M4 Carbine
    manufacturer VARCHAR(100),
    nsn VARCHAR(50) UNIQUE, -- National Stock Number
    description TEXT,
    specifications JSONB, -- Store technical specs, features as JSON
    image_url VARCHAR(512), -- URL to a representative image
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_property_models_type ON public.property_models(property_type_id);
CREATE INDEX IF NOT EXISTS idx_property_models_nsn ON public.property_models(nsn);

-- Function and Trigger to update 'updated_at' columns automatically (Optional but recommended)
CREATE OR REPLACE FUNCTION trigger_set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to tables (Run this for each table you want auto-updated_at)
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_property') THEN
    CREATE TRIGGER set_timestamp_property
    BEFORE UPDATE ON public.property
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_property_types') THEN
    CREATE TRIGGER set_timestamp_property_types
    BEFORE UPDATE ON public.property_types
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'set_timestamp_property_models') THEN
    CREATE TRIGGER set_timestamp_property_models
    BEFORE UPDATE ON public.property_models
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
  END IF;
END $$;
