-- NSN/LIN Catalog Schema Migration
-- File: 003_nsn_catalog.sql

-- Main NSN items table
CREATE TABLE IF NOT EXISTS nsn_items (
    nsn VARCHAR(13) PRIMARY KEY,
    niin VARCHAR(9) NOT NULL,
    fsc VARCHAR(4) NOT NULL,
    fsc_name VARCHAR(255),
    item_name TEXT NOT NULL,
    inc_code VARCHAR(5),
    lin VARCHAR(6),
    unit_of_issue VARCHAR(2),
    unit_price TEXT, -- Using TEXT to match Drizzle schema
    demil_code VARCHAR(1),
    shelf_life_code VARCHAR(1),
    hazmat_code VARCHAR(1),
    precious_metal_indicator VARCHAR(1),
    item_category VARCHAR(50),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Parts and manufacturers table
CREATE TABLE IF NOT EXISTS nsn_parts (
    id SERIAL PRIMARY KEY,
    nsn VARCHAR(13) REFERENCES nsn_items(nsn) ON DELETE CASCADE NOT NULL,
    part_number VARCHAR(50) NOT NULL,
    cage_code VARCHAR(5) NOT NULL,
    manufacturer_name TEXT,
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- LIN (Line Item Number) table
CREATE TABLE IF NOT EXISTS lin_items (
    lin VARCHAR(6) PRIMARY KEY,
    nomenclature TEXT NOT NULL,
    type_classification VARCHAR(50),
    ui VARCHAR(2),
    aac VARCHAR(1),
    slc VARCHAR(1),
    ciic VARCHAR(1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- CAGE codes reference table
CREATE TABLE IF NOT EXISTS cage_codes (
    cage_code VARCHAR(5) PRIMARY KEY,
    company_name TEXT NOT NULL,
    address TEXT,
    city VARCHAR(100),
    state VARCHAR(50),
    country VARCHAR(3),
    status VARCHAR(1),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Common synonyms and aliases for better search
CREATE TABLE IF NOT EXISTS nsn_synonyms (
    id SERIAL PRIMARY KEY,
    nsn VARCHAR(13) REFERENCES nsn_items(nsn) ON DELETE CASCADE NOT NULL,
    synonym TEXT NOT NULL,
    synonym_type VARCHAR(20), -- 'common_name', 'abbreviation', 'slang'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Catalog update history
CREATE TABLE IF NOT EXISTS catalog_updates (
    id SERIAL PRIMARY KEY,
    update_source VARCHAR(50) NOT NULL, -- 'PUBLOG', 'MANUAL', etc
    update_date TIMESTAMP NOT NULL,
    items_added INTEGER DEFAULT 0,
    items_updated INTEGER DEFAULT 0,
    items_removed INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_nsn_niin ON nsn_items(niin);
CREATE INDEX IF NOT EXISTS idx_nsn_fsc ON nsn_items(fsc);
CREATE INDEX IF NOT EXISTS idx_nsn_lin ON nsn_items(lin);
CREATE INDEX IF NOT EXISTS idx_nsn_item_name ON nsn_items(item_name);

-- Full text search index
CREATE INDEX IF NOT EXISTS idx_nsn_item_name_gin ON nsn_items USING gin(to_tsvector('english', item_name));
CREATE INDEX IF NOT EXISTS idx_nsn_description_gin ON nsn_items USING gin(to_tsvector('english', description));

CREATE INDEX IF NOT EXISTS idx_parts_nsn ON nsn_parts(nsn);
CREATE INDEX IF NOT EXISTS idx_parts_number ON nsn_parts(part_number);
CREATE INDEX IF NOT EXISTS idx_parts_cage ON nsn_parts(cage_code);

CREATE INDEX IF NOT EXISTS idx_lin_nomenclature ON lin_items(nomenclature);
CREATE INDEX IF NOT EXISTS idx_cage_company ON cage_codes(company_name);

-- Create trigger function for updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger for nsn_items updated_at
CREATE TRIGGER update_nsn_items_updated_at BEFORE UPDATE ON nsn_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create view for common queries
CREATE OR REPLACE VIEW nsn_full_view AS
SELECT 
    n.nsn,
    n.niin,
    n.fsc,
    n.fsc_name,
    n.item_name,
    n.lin,
    n.unit_of_issue,
    n.unit_price,
    n.description,
    l.nomenclature as lin_nomenclature,
    p.part_number as primary_part_number,
    p.cage_code as primary_cage_code,
    p.manufacturer_name as primary_manufacturer
FROM nsn_items n
LEFT JOIN lin_items l ON n.lin = l.lin
LEFT JOIN nsn_parts p ON n.nsn = p.nsn AND p.is_primary = true; 