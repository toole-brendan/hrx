-- Create documents table for DA2062 and maintenance forms
CREATE TABLE IF NOT EXISTS documents (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE,
    type VARCHAR(50) NOT NULL,
    subtype VARCHAR(50),
    title VARCHAR(255) NOT NULL,
    sender_user_id INTEGER NOT NULL,
    recipient_user_id INTEGER NOT NULL,
    property_id INTEGER,
    form_data TEXT,
    description TEXT,
    attachments JSONB DEFAULT '[]'::jsonb,
    status VARCHAR(50) NOT NULL DEFAULT 'unread',
    sent_at TIMESTAMP WITH TIME ZONE NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE,
    CONSTRAINT fk_documents_sender FOREIGN KEY (sender_user_id) REFERENCES users(id),
    CONSTRAINT fk_documents_recipient FOREIGN KEY (recipient_user_id) REFERENCES users(id),
    CONSTRAINT fk_documents_property FOREIGN KEY (property_id) REFERENCES properties(id)
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_documents_sender_user_id ON documents(sender_user_id);
CREATE INDEX IF NOT EXISTS idx_documents_recipient_user_id ON documents(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_documents_property_id ON documents(property_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(type);
CREATE INDEX IF NOT EXISTS idx_documents_sent_at ON documents(sent_at);
CREATE INDEX IF NOT EXISTS idx_documents_deleted_at ON documents(deleted_at);

-- Add comment to table
COMMENT ON TABLE documents IS 'Stores various document types including DA2062 forms and maintenance forms'; 