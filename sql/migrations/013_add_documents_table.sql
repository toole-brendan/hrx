-- Migration: 013_add_documents_table.sql
-- Description: Add documents table for maintenance forms and other document types

-- Create documents table
CREATE TABLE documents (
    id SERIAL PRIMARY KEY,
    type TEXT NOT NULL, -- 'maintenance_form', 'transfer_form', etc.
    subtype TEXT, -- 'DA2404', 'DA5988E', etc.
    title TEXT NOT NULL,
    sender_user_id INTEGER NOT NULL REFERENCES users(id),
    recipient_user_id INTEGER NOT NULL REFERENCES users(id),
    property_id INTEGER REFERENCES properties(id),
    form_data JSONB NOT NULL, -- Complete form data
    description TEXT,
    attachments JSONB, -- Array of photo URLs
    status TEXT NOT NULL DEFAULT 'unread', -- unread, read, archived
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes for performance
CREATE INDEX idx_documents_recipient_user_id ON documents(recipient_user_id);
CREATE INDEX idx_documents_sender_user_id ON documents(sender_user_id);
CREATE INDEX idx_documents_property_id ON documents(property_id);
CREATE INDEX idx_documents_status ON documents(status);
CREATE INDEX idx_documents_type ON documents(type);
CREATE INDEX idx_documents_sent_at ON documents(sent_at DESC);

-- Index for common query patterns
CREATE INDEX idx_documents_recipient_status ON documents(recipient_user_id, status);
CREATE INDEX idx_documents_sender_type ON documents(sender_user_id, type);

-- Add comments for documentation
COMMENT ON TABLE documents IS 'Stores maintenance forms and other documents sent between users';
COMMENT ON COLUMN documents.type IS 'Document type: maintenance_form, transfer_form, etc.';
COMMENT ON COLUMN documents.subtype IS 'Specific form type: DA2404, DA5988E, etc.';
COMMENT ON COLUMN documents.form_data IS 'JSONB containing complete form data structure';
COMMENT ON COLUMN documents.attachments IS 'JSONB array of photo/file URLs';
COMMENT ON COLUMN documents.status IS 'Document status: unread, read, archived'; 