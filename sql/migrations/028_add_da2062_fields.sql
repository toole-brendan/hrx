-- Migration: Add DA 2062 required fields to properties table
-- This migration adds fields necessary for accurate DA 2062 form generation

-- Add core DA 2062 fields
ALTER TABLE properties 
ADD COLUMN unit_of_issue VARCHAR(10) DEFAULT 'EA' CHECK (unit_of_issue IN ('EA', 'PR', 'DZ', 'HD', 'TH', 'GAL', 'QT', 'PT', 'LTR', 'LB', 'OZ', 'KG', 'FT', 'YD', 'M', 'RD', 'BX', 'CN', 'PG', 'RL')),
ADD COLUMN condition_code VARCHAR(10) DEFAULT 'A' CHECK (condition_code IN ('A', 'B', 'C')),
ADD COLUMN category VARCHAR(50),
ADD COLUMN manufacturer VARCHAR(100),
ADD COLUMN part_number VARCHAR(50),
ADD COLUMN security_classification VARCHAR(10) DEFAULT 'U' CHECK (security_classification IN ('U', 'FOUO', 'C', 'S'));

-- Add indexes for common queries
CREATE INDEX idx_properties_category ON properties(category);
CREATE INDEX idx_properties_condition ON properties(condition_code);
CREATE INDEX idx_properties_security ON properties(security_classification);

-- Create unit of issue reference table
CREATE TABLE IF NOT EXISTS unit_of_issue_codes (
    code VARCHAR(10) PRIMARY KEY,
    description VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    sort_order INTEGER DEFAULT 0
);

-- Populate unit of issue codes
INSERT INTO unit_of_issue_codes (code, description, category, sort_order) VALUES
-- General counting units
('EA', 'Each', 'General', 1),
('PR', 'Pair', 'General', 2),
('DZ', 'Dozen', 'General', 3),
('HD', 'Hundred', 'General', 4),
('TH', 'Thousand', 'General', 5),
-- Liquid measurements
('GAL', 'Gallon', 'Liquid', 10),
('QT', 'Quart', 'Liquid', 11),
('PT', 'Pint', 'Liquid', 12),
('LTR', 'Liter', 'Liquid', 13),
('ML', 'Milliliter', 'Liquid', 14),
-- Weight measurements
('LB', 'Pound', 'Weight', 20),
('OZ', 'Ounce', 'Weight', 21),
('KG', 'Kilogram', 'Weight', 22),
('G', 'Gram', 'Weight', 23),
('TN', 'Ton', 'Weight', 24),
-- Length measurements
('FT', 'Feet', 'Length', 30),
('IN', 'Inch', 'Length', 31),
('YD', 'Yard', 'Length', 32),
('M', 'Meter', 'Length', 33),
('CM', 'Centimeter', 'Length', 34),
-- Ammunition
('RD', 'Round', 'Ammunition', 40),
-- Containers
('BX', 'Box', 'Container', 50),
('CN', 'Can', 'Container', 51),
('PG', 'Package', 'Container', 52),
('RL', 'Roll', 'Container', 53),
('BG', 'Bag', 'Container', 54),
('BT', 'Bottle', 'Container', 55),
-- Area measurements
('SF', 'Square Feet', 'Area', 60),
('SY', 'Square Yard', 'Area', 61),
('SM', 'Square Meter', 'Area', 62)
ON CONFLICT (code) DO NOTHING;

-- Create property categories reference table
CREATE TABLE IF NOT EXISTS property_categories (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_sensitive BOOLEAN DEFAULT FALSE,
    default_security_class VARCHAR(10) DEFAULT 'U',
    sort_order INTEGER DEFAULT 0
);

-- Populate property categories
INSERT INTO property_categories (code, name, description, is_sensitive, default_security_class, sort_order) VALUES
('WEAPON', 'Weapons', 'Firearms, weapons systems, and armament', TRUE, 'FOUO', 1),
('VEHICLE', 'Vehicles', 'Wheeled and tracked vehicles', FALSE, 'U', 2),
('COMMS', 'Communications', 'Radios, phones, and communication equipment', TRUE, 'FOUO', 3),
('OPTICS', 'Optics', 'Scopes, binoculars, and vision equipment', TRUE, 'FOUO', 4),
('MEDICAL', 'Medical', 'Medical supplies and equipment', FALSE, 'U', 5),
('CBRN', 'CBRN', 'Chemical, Biological, Radiological, Nuclear equipment', TRUE, 'C', 6),
('TOOL', 'Tools', 'Hand tools and power tools', FALSE, 'U', 7),
('CLOTHING', 'Clothing & Equipment', 'Uniforms, gear, and personal equipment', FALSE, 'U', 8),
('AMMO', 'Ammunition', 'Ammunition and explosives', TRUE, 'FOUO', 9),
('ELECTRONICS', 'Electronics', 'Computers, tablets, and electronic devices', FALSE, 'FOUO', 10),
('GENERATOR', 'Generators', 'Power generation equipment', FALSE, 'U', 11),
('TENTAGE', 'Tentage', 'Tents, shelters, and field equipment', FALSE, 'U', 12),
('KITCHEN', 'Kitchen', 'Field kitchen and food service equipment', FALSE, 'U', 13),
('FUEL', 'Fuel & Lubricants', 'POL products and containers', FALSE, 'U', 14),
('OTHER', 'Other', 'Miscellaneous equipment', FALSE, 'U', 99)
ON CONFLICT (code) DO NOTHING;

-- Create condition history tracking table
CREATE TABLE IF NOT EXISTS property_condition_history (
    id SERIAL PRIMARY KEY,
    property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    previous_condition VARCHAR(10),
    new_condition VARCHAR(10) NOT NULL,
    changed_by INTEGER REFERENCES users(id),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reason VARCHAR(255),
    notes TEXT,
    
    CONSTRAINT valid_conditions CHECK (
        new_condition IN ('A', 'B', 'C') AND 
        (previous_condition IS NULL OR previous_condition IN ('A', 'B', 'C'))
    )
);

-- Add index for condition history queries
CREATE INDEX idx_condition_history_property ON property_condition_history(property_id);
CREATE INDEX idx_condition_history_date ON property_condition_history(changed_at);

-- Update existing properties with intelligent defaults based on current data
-- Set unit_of_issue based on property characteristics
UPDATE properties 
SET unit_of_issue = CASE
    -- Ammunition
    WHEN LOWER(name) LIKE '%round%' OR LOWER(name) LIKE '%ammo%' OR LOWER(name) LIKE '%cartridge%' THEN 'RD'
    -- Liquids
    WHEN LOWER(name) LIKE '%oil%' OR LOWER(name) LIKE '%fuel%' OR LOWER(name) LIKE '%coolant%' THEN 'GAL'
    -- Cables and rope
    WHEN LOWER(name) LIKE '%cable%' OR LOWER(name) LIKE '%rope%' OR LOWER(name) LIKE '%wire%' THEN 'FT'
    -- Paired items
    WHEN LOWER(name) LIKE '%glove%' OR LOWER(name) LIKE '%boot%' OR LOWER(name) LIKE '%shoe%' THEN 'PR'
    -- Default
    ELSE 'EA'
END
WHERE unit_of_issue IS NULL;

-- Set category based on property characteristics
UPDATE properties 
SET category = CASE
    -- Weapons
    WHEN LOWER(name) LIKE '%rifle%' OR LOWER(name) LIKE '%pistol%' OR LOWER(name) LIKE '%carbine%' 
         OR LOWER(name) LIKE '%m4%' OR LOWER(name) LIKE '%m16%' OR LOWER(name) LIKE '%m9%' THEN 'WEAPON'
    -- Vehicles
    WHEN LOWER(name) LIKE '%truck%' OR LOWER(name) LIKE '%hmmwv%' OR LOWER(name) LIKE '%vehicle%' 
         OR LOWER(name) LIKE '%trailer%' THEN 'VEHICLE'
    -- Communications
    WHEN LOWER(name) LIKE '%radio%' OR LOWER(name) LIKE '%antenna%' OR LOWER(name) LIKE '%phone%' THEN 'COMMS'
    -- Optics
    WHEN LOWER(name) LIKE '%scope%' OR LOWER(name) LIKE '%binocular%' OR LOWER(name) LIKE '%nvg%' 
         OR LOWER(name) LIKE '%night vision%' OR LOWER(name) LIKE '%acog%' THEN 'OPTICS'
    -- Medical
    WHEN LOWER(name) LIKE '%medical%' OR LOWER(name) LIKE '%first aid%' OR LOWER(name) LIKE '%bandage%' THEN 'MEDICAL'
    -- Tools
    WHEN LOWER(name) LIKE '%tool%' OR LOWER(name) LIKE '%wrench%' OR LOWER(name) LIKE '%hammer%' 
         OR LOWER(name) LIKE '%screwdriver%' THEN 'TOOL'
    -- Ammunition
    WHEN LOWER(name) LIKE '%ammo%' OR LOWER(name) LIKE '%round%' OR LOWER(name) LIKE '%grenade%' THEN 'AMMO'
    -- Generators
    WHEN LOWER(name) LIKE '%generator%' OR LOWER(name) LIKE '%genset%' THEN 'GENERATOR'
    -- Default
    ELSE 'OTHER'
END
WHERE category IS NULL;

-- Set security classification based on category
UPDATE properties p
SET security_classification = COALESCE(
    (SELECT default_security_class FROM property_categories pc WHERE pc.code = p.category),
    'U'
)
WHERE security_classification IS NULL;

-- Add comment to properties table
COMMENT ON COLUMN properties.unit_of_issue IS 'Unit of Issue code per military standards (EA, GAL, etc.)';
COMMENT ON COLUMN properties.condition_code IS 'Condition code: A=Serviceable, B=Unserviceable(Repairable), C=Unserviceable(Condemned)';
COMMENT ON COLUMN properties.category IS 'Property category for grouping and reporting';
COMMENT ON COLUMN properties.security_classification IS 'Security classification: U=Unclassified, FOUO=For Official Use Only, C=Confidential, S=Secret';