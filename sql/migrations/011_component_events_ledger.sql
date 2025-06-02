-- Migration: Add ComponentEvents table for PostgreSQL
-- Created: Component Association Feature Implementation
-- Description: Creates a table to track component attachment/detachment events for audit trail

-- Create ComponentEvents table (PostgreSQL compatible)
CREATE TABLE IF NOT EXISTS component_events (
    event_id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    parent_property_id INTEGER NOT NULL,
    component_property_id INTEGER NOT NULL,
    attaching_user_id INTEGER NOT NULL,
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN ('ATTACHED', 'DETACHED')),
    position VARCHAR(100),
    notes TEXT,
    event_timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_component_events_parent_property 
        FOREIGN KEY (parent_property_id) REFERENCES properties(id),
    CONSTRAINT fk_component_events_component_property 
        FOREIGN KEY (component_property_id) REFERENCES properties(id),
    CONSTRAINT fk_component_events_user 
        FOREIGN KEY (attaching_user_id) REFERENCES users(id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_component_events_parent_property_id 
    ON component_events(parent_property_id);

CREATE INDEX IF NOT EXISTS idx_component_events_component_property_id 
    ON component_events(component_property_id);

CREATE INDEX IF NOT EXISTS idx_component_events_event_timestamp 
    ON component_events(event_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_component_events_user_id 
    ON component_events(attaching_user_id);

-- Create a view for component event history (PostgreSQL compatible)
CREATE OR REPLACE VIEW component_event_history AS
SELECT
    event_id,
    'ComponentEvent' AS event_type,
    event_timestamp AS timestamp,
    attaching_user_id AS user_id,
    parent_property_id AS item_id,
    json_build_object(
        'eventTypeDetail', event_type,
        'parentPropertyId', parent_property_id,
        'componentPropertyId', component_property_id,
        'position', position,
        'notes', notes
    ) AS details_json
FROM component_events
ORDER BY event_timestamp DESC;

-- Add comments for documentation
COMMENT ON TABLE component_events IS 'Tracks component attachment and detachment events for audit trail';
COMMENT ON COLUMN component_events.event_type IS 'Type of event: ATTACHED or DETACHED';
COMMENT ON COLUMN component_events.position IS 'Position where component was attached/detached';
COMMENT ON COLUMN component_events.notes IS 'Additional notes about the event';
COMMENT ON VIEW component_event_history IS 'Formatted view of component events for reporting';

-- Insert a test event to verify the table works
-- This can be removed in production
-- INSERT INTO component_events (parent_property_id, component_property_id, attaching_user_id, event_type, notes)
-- SELECT 1, 2, 1, 'ATTACHED', 'Migration test event'
-- WHERE EXISTS (SELECT 1 FROM properties WHERE id = 1) 
--   AND EXISTS (SELECT 1 FROM properties WHERE id = 2)
--   AND EXISTS (SELECT 1 FROM users WHERE id = 1); 