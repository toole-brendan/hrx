-- Production seed data for HandReceipt
-- This file contains test users for development testing

-- Create test user: michael.rodriguez
-- Password: password123 (bcrypt hash)
INSERT INTO users (username, password, name, rank) 
VALUES (
    'michael.rodriguez',
    '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', -- bcrypt hash of 'password123'
    'Michael Rodriguez', 
    'CPT'
) ON CONFLICT (username) DO NOTHING;

-- Create another test user
INSERT INTO users (username, password, name, rank) 
VALUES (
    'john.doe',
    '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', -- bcrypt hash of 'password123'
    'John Doe', 
    'SFC'
) ON CONFLICT (username) DO NOTHING;

-- Let's also add a few more test users for variety
INSERT INTO users (username, password, name, rank) 
VALUES 
    ('jane.smith', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'Jane Smith', 'SGT'),
    ('bob.wilson', '$2a$10$3PfvgaGmwO9Ctfla.DpfYeJRTmWel7UsntTpHHWBJtQNK764e.Fg6', 'Bob Wilson', '1LT')
ON CONFLICT (username) DO NOTHING; 