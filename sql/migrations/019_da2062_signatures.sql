-- sql/migrations/019_da2062_signatures.sql
CREATE TABLE IF NOT EXISTS da2062_signatures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE,
    
    -- User references for FROM/TO signatures only
    from_user_id UUID REFERENCES users(id) NOT NULL,
    to_user_id UUID REFERENCES users(id) NOT NULL,
    
    -- Signature image URLs
    from_signature_url TEXT,
    to_signature_url TEXT,
    
    -- Diagonal signature metadata
    signature_metadata JSONB DEFAULT '{}',
    /* Example structure:
    {
      "from": {
        "angle": -45,
        "x": 10,
        "y": 240,
        "width": 80,
        "height": 20,
        "applied_at": "2024-01-15T10:30:00Z"
      },
      "to": {
        "angle": -45,
        "x": 110,
        "y": 240,
        "width": 80,
        "height": 20,
        "applied_at": "2024-01-15T10:30:00Z"
      }
    }
    */
    
    -- Timestamps
    signed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_da2062_signatures_document ON da2062_signatures(document_id);
CREATE INDEX idx_da2062_signatures_users ON da2062_signatures(from_user_id, to_user_id);

-- Update documents table to track signature status
ALTER TABLE documents ADD COLUMN IF NOT EXISTS signature_status VARCHAR(50) DEFAULT 'unsigned';
ALTER TABLE documents ADD COLUMN IF NOT EXISTS signature_data JSONB DEFAULT '{}'; 