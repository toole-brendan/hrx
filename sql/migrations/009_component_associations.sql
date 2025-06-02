-- Migration: 009_component_associations.sql
-- Description: Add component associations feature to allow attaching accessories to parent items

-- Add component association fields to properties table
ALTER TABLE properties 
ADD COLUMN is_attachable BOOLEAN DEFAULT FALSE,
ADD COLUMN attachment_points JSONB,
ADD COLUMN compatible_with JSONB;

-- Add indexes for performance on JSON fields
CREATE INDEX idx_properties_is_attachable ON properties(is_attachable) WHERE is_attachable = true;
CREATE INDEX idx_properties_compatible_with ON properties USING gin(compatible_with);

-- Create property_components table for component associations
CREATE TABLE property_components (
    id SERIAL PRIMARY KEY,
    parent_property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    component_property_id INTEGER NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    attached_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    attached_by_user_id INTEGER NOT NULL REFERENCES users(id),
    notes TEXT,
    attachment_type VARCHAR(50) DEFAULT 'field',
    position VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
    
    -- Ensure a component can only be attached to one parent at a time
    UNIQUE(component_property_id),
    
    -- Prevent self-referencing
    CHECK (parent_property_id != component_property_id)
);

-- Add indexes for performance
CREATE INDEX idx_property_components_parent ON property_components(parent_property_id);
CREATE INDEX idx_property_components_component ON property_components(component_property_id);
CREATE INDEX idx_property_components_attached_by ON property_components(attached_by_user_id);

-- Add comments for documentation
COMMENT ON TABLE property_components IS 'Tracks attachment relationships between parent items and their components/accessories';
COMMENT ON COLUMN properties.is_attachable IS 'Indicates if this item can have components attached to it';
COMMENT ON COLUMN properties.attachment_points IS 'JSON array of available attachment positions like ["rail_top", "rail_side", "barrel"]';
COMMENT ON COLUMN properties.compatible_with IS 'JSON array of parent item types this component is compatible with';
COMMENT ON COLUMN property_components.attachment_type IS 'Type of attachment: permanent, temporary, or field';
COMMENT ON COLUMN property_components.position IS 'Specific position where component is attached, e.g., rail_top, barrel, etc.';

-- Insert some example data for testing (can be removed in production)
-- Update some properties to be attachable (example weapons)
UPDATE properties 
SET is_attachable = true, 
    attachment_points = '["rail_top", "rail_side", "barrel", "grip", "stock"]'::jsonb
WHERE name ILIKE '%rifle%' OR name ILIKE '%carbine%' OR name ILIKE '%m4%' OR name ILIKE '%m16%';

-- Update some properties as components with compatibility info
UPDATE properties 
SET compatible_with = '["M4", "M16", "AR15", "rifle", "carbine"]'::jsonb
WHERE name ILIKE '%scope%' OR name ILIKE '%sight%' OR name ILIKE '%optic%' OR name ILIKE '%acog%';

UPDATE properties 
SET compatible_with = '["M4", "M16", "AR15", "rifle", "carbine", "pistol"]'::jsonb
WHERE name ILIKE '%grip%' OR name ILIKE '%foregrip%' OR name ILIKE '%light%' OR name ILIKE '%laser%';

UPDATE properties 
SET compatible_with = '["M4", "M16", "AR15", "rifle", "carbine"]'::jsonb
WHERE name ILIKE '%suppressor%' OR name ILIKE '%silencer%' OR name ILIKE '%muzzle%'; 