-- Production seed data for HandReceipt application
-- This creates essential users and basic data for production deployment

-- Create admin user
INSERT INTO users (email, password, name, rank)
VALUES (
    'admin@handreceipt.com',
    '$2b$10$xfTImAQbmP6d7S8JGSLDXeu0yDqLRQbYdJ4Jt.1J0C8vMnGJzPXOS', -- "password" - CHANGE IN PRODUCTION
    'System Administrator',
    'ADMIN'
) ON CONFLICT (email) DO NOTHING;

-- Create demo user for testing
INSERT INTO users (email, password, name, rank)
VALUES (
    'demo@handreceipt.com',
    '$2b$10$xfTImAQbmP6d7S8JGSLDXeu0yDqLRQbYdJ4Jt.1J0C8vMnGJzPXOS', -- "password" - CHANGE IN PRODUCTION
    'Demo User',
    'CPT'
) ON CONFLICT (email) DO NOTHING;

-- Create sample user for documentation
INSERT INTO users (email, password, name, rank)
VALUES (
    'sample@handreceipt.com',
    '$2b$10$xfTImAQbmP6d7S8JGSLDXeu0yDqLRQbYdJ4Jt.1J0C8vMnGJzPXOS', -- "password" - CHANGE IN PRODUCTION  
    'Sample User',
    'SGT'
) ON CONFLICT (email) DO NOTHING; 