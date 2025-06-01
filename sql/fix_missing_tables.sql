-- Fix missing core tables

-- Create properties table
CREATE TABLE IF NOT EXISTS properties (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    serial_number VARCHAR(255) NOT NULL UNIQUE,
    description TEXT,
    current_status VARCHAR(50) NOT NULL DEFAULT 'active',
    condition VARCHAR(50) DEFAULT 'serviceable',
    condition_notes TEXT,
    nsn VARCHAR(20),
    lin VARCHAR(10),
    location VARCHAR(255),
    acquisition_date TIMESTAMP WITH TIME ZONE,
    unit_price DECIMAL(12, 2) DEFAULT 0,
    quantity INTEGER DEFAULT 1,
    photo_url TEXT,
    assigned_to_user_id INTEGER REFERENCES users(id),
    last_verified_at TIMESTAMP WITH TIME ZONE,
    is_sensitive BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create transfers table
CREATE TABLE IF NOT EXISTS transfers (
    id SERIAL PRIMARY KEY,
    transfer_type VARCHAR(50) NOT NULL DEFAULT 'standard',
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    from_user_id INTEGER REFERENCES users(id),
    to_user_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    rejection_reason TEXT,
    serial_request_type VARCHAR(50)
);

-- Create transfer_items table
CREATE TABLE IF NOT EXISTS transfer_items (
    id SERIAL PRIMARY KEY,
    transfer_id INTEGER NOT NULL REFERENCES transfers(id) ON DELETE CASCADE,
    property_id INTEGER NOT NULL REFERENCES properties(id),
    quantity INTEGER DEFAULT 1,
    status VARCHAR(50) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(transfer_id, property_id)
);

-- Create activities table
CREATE TABLE IF NOT EXISTS activities (
    id SERIAL PRIMARY KEY,
    type VARCHAR(50) NOT NULL,
    description TEXT NOT NULL,
    user_id INTEGER REFERENCES users(id),
    related_property_id INTEGER REFERENCES properties(id),
    related_transfer_id INTEGER REFERENCES transfers(id),
    metadata JSONB,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create transfer_offers table
CREATE TABLE IF NOT EXISTS transfer_offers (
    id SERIAL PRIMARY KEY,
    property_id INTEGER NOT NULL REFERENCES properties(id),
    offering_user_id INTEGER NOT NULL REFERENCES users(id),
    status VARCHAR(50) DEFAULT 'active',
    offer_type VARCHAR(50) DEFAULT 'anyone',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE
);

-- Create transfer_offer_recipients table
CREATE TABLE IF NOT EXISTS transfer_offer_recipients (
    id SERIAL PRIMARY KEY,
    offer_id INTEGER NOT NULL REFERENCES transfer_offers(id) ON DELETE CASCADE,
    user_id INTEGER NOT NULL REFERENCES users(id),
    UNIQUE(offer_id, user_id)
);

-- Add password column to users if missing
ALTER TABLE users ADD COLUMN IF NOT EXISTS password VARCHAR(255);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_properties_serial_number ON properties(serial_number);
CREATE INDEX IF NOT EXISTS idx_properties_assigned_user ON properties(assigned_to_user_id);
CREATE INDEX IF NOT EXISTS idx_transfers_from_user ON transfers(from_user_id);
CREATE INDEX IF NOT EXISTS idx_transfers_to_user ON transfers(to_user_id);
CREATE INDEX IF NOT EXISTS idx_transfers_status ON transfers(status);
CREATE INDEX IF NOT EXISTS idx_activities_user_id ON activities(user_id);
CREATE INDEX IF NOT EXISTS idx_activities_property_id ON activities(related_property_id);
CREATE INDEX IF NOT EXISTS idx_activities_transfer_id ON activities(related_transfer_id);
CREATE INDEX IF NOT EXISTS idx_activities_timestamp ON activities(timestamp);
CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(type); 