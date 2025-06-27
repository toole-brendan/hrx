-- Create refresh_tokens table for JWT token-based authentication
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    revoked_at TIMESTAMP,
    
    -- Indexes for performance
    CONSTRAINT idx_refresh_token UNIQUE (token)
);

-- Create indexes for efficient queries
CREATE INDEX idx_user_refresh_tokens ON refresh_tokens(user_id, revoked_at);
CREATE INDEX idx_refresh_token_expires ON refresh_tokens(expires_at) WHERE revoked_at IS NULL;

-- Add comment to table
COMMENT ON TABLE refresh_tokens IS 'Stores refresh tokens for JWT authentication';
COMMENT ON COLUMN refresh_tokens.user_id IS 'Reference to the user who owns this token';
COMMENT ON COLUMN refresh_tokens.token IS 'The refresh token string (hashed)';
COMMENT ON COLUMN refresh_tokens.expires_at IS 'When this token expires';
COMMENT ON COLUMN refresh_tokens.revoked_at IS 'When this token was revoked (null if active)';

-- Create a function to clean up expired tokens (can be called periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_refresh_tokens()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM refresh_tokens 
    WHERE expires_at < NOW() OR revoked_at IS NOT NULL;
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Add session_id column to users table if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'users' AND column_name = 'session_id') THEN
        ALTER TABLE users ADD COLUMN session_id VARCHAR(255);
        CREATE INDEX idx_users_session_id ON users(session_id);
    END IF;
END $$;