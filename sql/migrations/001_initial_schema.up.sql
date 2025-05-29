-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create custom types
CREATE TYPE user_role AS ENUM ('user', 'admin', 'super_admin', 'property_officer', 'commander');
CREATE TYPE user_status AS ENUM ('active', 'inactive', 'suspended', 'pending');
CREATE TYPE equipment_status AS ENUM ('available', 'assigned', 'in_transit', 'maintenance', 'retired', 'lost', 'damaged');
CREATE TYPE equipment_condition AS ENUM ('serviceable', 'unserviceable', 'needs_repair', 'beyond_repair', 'new');
CREATE TYPE transfer_type AS ENUM ('assignment', 'return', 'transfer', 'loan', 'temporary');
CREATE TYPE transfer_status AS ENUM ('pending', 'approved', 'completed', 'rejected', 'cancelled');
CREATE TYPE maintenance_type AS ENUM ('preventive', 'corrective', 'inspection', 'calibration', 'overhaul');
CREATE TYPE maintenance_status AS ENUM ('scheduled', 'in_progress', 'completed', 'cancelled', 'overdue');
CREATE TYPE audit_action AS ENUM ('create', 'update', 'delete', 'view', 'login', 'logout', 'transfer', 'assign', 'return');

-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    rank VARCHAR(50),
    unit VARCHAR(100),
    role user_role DEFAULT 'user' NOT NULL,
    status user_status DEFAULT 'active' NOT NULL,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Equipment table
CREATE TABLE equipment (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    nsn VARCHAR(13),
    lin VARCHAR(6),
    serial_number VARCHAR(100) NOT NULL,
    nomenclature TEXT,
    description TEXT,
    manufacturer VARCHAR(100),
    model VARCHAR(100),
    part_number VARCHAR(100),
    unit_price DECIMAL(12,2) DEFAULT 0,
    quantity INTEGER DEFAULT 1 NOT NULL,
    location VARCHAR(255),
    status equipment_status DEFAULT 'available' NOT NULL,
    condition equipment_condition DEFAULT 'serviceable' NOT NULL,
    assigned_to_id INTEGER REFERENCES users(id),
    acquisition_date TIMESTAMP WITH TIME ZONE,
    warranty_expiry TIMESTAMP WITH TIME ZONE,
    last_inspection TIMESTAMP WITH TIME ZONE,
    next_inspection TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Hand receipts table
CREATE TABLE hand_receipts (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    equipment_id INTEGER NOT NULL REFERENCES equipment(id),
    from_user_id INTEGER REFERENCES users(id),
    to_user_id INTEGER NOT NULL REFERENCES users(id),
    transfer_type transfer_type NOT NULL,
    status transfer_status DEFAULT 'pending' NOT NULL,
    transfer_date TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    effective_date TIMESTAMP WITH TIME ZONE,
    expiry_date TIMESTAMP WITH TIME ZONE,
    signature_data TEXT,
    digital_signature TEXT,
    notes TEXT,
    reason TEXT,
    location VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Transfer witnesses table
CREATE TABLE transfer_witnesses (
    id SERIAL PRIMARY KEY,
    hand_receipt_id INTEGER NOT NULL REFERENCES hand_receipts(id),
    user_id INTEGER NOT NULL REFERENCES users(id),
    signature_data TEXT,
    signed_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Maintenance records table
CREATE TABLE maintenance_records (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    equipment_id INTEGER NOT NULL REFERENCES equipment(id),
    technician_id INTEGER NOT NULL REFERENCES users(id),
    type maintenance_type NOT NULL,
    status maintenance_status DEFAULT 'scheduled' NOT NULL,
    scheduled_date TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_date TIMESTAMP WITH TIME ZONE,
    description TEXT,
    work_performed TEXT,
    parts_used TEXT,
    cost DECIMAL(10,2) DEFAULT 0,
    next_due_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Attachments table
CREATE TABLE attachments (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    equipment_id INTEGER NOT NULL REFERENCES equipment(id),
    file_name VARCHAR(255) NOT NULL,
    original_name VARCHAR(255) NOT NULL,
    file_size BIGINT,
    mime_type VARCHAR(100),
    file_path VARCHAR(500) NOT NULL,
    file_hash VARCHAR(64),
    uploaded_by_id INTEGER NOT NULL REFERENCES users(id),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Audit logs table (for PostgreSQL audit trail)
CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    entity_type VARCHAR(50) NOT NULL,
    entity_id VARCHAR(50) NOT NULL,
    action audit_action NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- NSN data cache table
CREATE TABLE nsn_data (
    id SERIAL PRIMARY KEY,
    nsn VARCHAR(13) UNIQUE NOT NULL,
    lin VARCHAR(6),
    nomenclature TEXT,
    fsc VARCHAR(4),
    niin VARCHAR(9),
    unit_price DECIMAL(12,2),
    manufacturer VARCHAR(255),
    part_number VARCHAR(100),
    specifications JSONB,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Sessions table
CREATE TABLE sessions (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    token VARCHAR(255) UNIQUE NOT NULL,
    ip_address INET,
    user_agent TEXT,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Refresh tokens table
CREATE TABLE refresh_tokens (
    id SERIAL PRIMARY KEY,
    uuid UUID DEFAULT uuid_generate_v4() UNIQUE NOT NULL,
    user_id INTEGER NOT NULL REFERENCES users(id),
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    is_revoked BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_deleted_at ON users(deleted_at);

CREATE INDEX idx_equipment_nsn ON equipment(nsn);
CREATE INDEX idx_equipment_lin ON equipment(lin);
CREATE INDEX idx_equipment_serial_number ON equipment(serial_number);
CREATE INDEX idx_equipment_status ON equipment(status);
CREATE INDEX idx_equipment_condition ON equipment(condition);
CREATE INDEX idx_equipment_assigned_to_id ON equipment(assigned_to_id);
CREATE INDEX idx_equipment_deleted_at ON equipment(deleted_at);

CREATE INDEX idx_hand_receipts_equipment_id ON hand_receipts(equipment_id);
CREATE INDEX idx_hand_receipts_from_user_id ON hand_receipts(from_user_id);
CREATE INDEX idx_hand_receipts_to_user_id ON hand_receipts(to_user_id);
CREATE INDEX idx_hand_receipts_status ON hand_receipts(status);
CREATE INDEX idx_hand_receipts_transfer_date ON hand_receipts(transfer_date);
CREATE INDEX idx_hand_receipts_deleted_at ON hand_receipts(deleted_at);

CREATE INDEX idx_maintenance_records_equipment_id ON maintenance_records(equipment_id);
CREATE INDEX idx_maintenance_records_technician_id ON maintenance_records(technician_id);
CREATE INDEX idx_maintenance_records_status ON maintenance_records(status);
CREATE INDEX idx_maintenance_records_scheduled_date ON maintenance_records(scheduled_date);

CREATE INDEX idx_attachments_equipment_id ON attachments(equipment_id);
CREATE INDEX idx_attachments_uploaded_by_id ON attachments(uploaded_by_id);
CREATE INDEX idx_attachments_deleted_at ON attachments(deleted_at);

CREATE INDEX idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX idx_audit_logs_entity_id ON audit_logs(entity_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

CREATE INDEX idx_nsn_data_nsn ON nsn_data(nsn);
CREATE INDEX idx_nsn_data_lin ON nsn_data(lin);

CREATE INDEX idx_sessions_user_id ON sessions(user_id);
CREATE INDEX idx_sessions_token ON sessions(token);
CREATE INDEX idx_sessions_expires_at ON sessions(expires_at);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token ON refresh_tokens(token);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_equipment_updated_at BEFORE UPDATE ON equipment FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_hand_receipts_updated_at BEFORE UPDATE ON hand_receipts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_maintenance_records_updated_at BEFORE UPDATE ON maintenance_records FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_attachments_updated_at BEFORE UPDATE ON attachments FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_nsn_data_updated_at BEFORE UPDATE ON nsn_data FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_refresh_tokens_updated_at BEFORE UPDATE ON refresh_tokens FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert default admin user (password: admin123)
INSERT INTO users (username, email, password_hash, first_name, last_name, role, status) 
VALUES (
    'admin', 
    'admin@handreceipt.mil', 
    '$2a$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', -- bcrypt hash of 'admin123'
    'System', 
    'Administrator', 
    'super_admin', 
    'active'
);

-- Insert sample NSN data
INSERT INTO nsn_data (nsn, lin, nomenclature, fsc, niin, unit_price, manufacturer, part_number) VALUES
('1005-01-123-4567', 'A12345', 'RIFLE,5.56 MILLIMETER,M4', '1005', '011234567', 986.00, 'COLT DEFENSE LLC', 'M4A1'),
('2320-01-234-5678', 'B23456', 'TRUCK,CARGO,TACTICAL,M1078', '2320', '012345678', 125000.00, 'STEWART & STEVENSON', 'M1078'),
('5855-01-345-6789', 'C34567', 'COMPUTER,DIGITAL,RUGGED', '5855', '013456789', 3500.00, 'GETAC INC', 'B300'),
('8465-01-456-7890', 'D45678', 'CLOTHING,SPECIAL PURPOSE', '8465', '014567890', 125.50, 'PROPPER INTERNATIONAL', 'ACU-A'),
('1240-01-567-8901', 'E56789', 'TANK,COMBAT,FULL TRACKED', '1240', '015678901', 6200000.00, 'GENERAL DYNAMICS', 'M1A2');

COMMENT ON TABLE users IS 'Military personnel and system users';
COMMENT ON TABLE equipment IS 'Military equipment and property items';
COMMENT ON TABLE hand_receipts IS 'Property transfer records and hand receipts';
COMMENT ON TABLE maintenance_records IS 'Equipment maintenance history and schedules';
COMMENT ON TABLE audit_logs IS 'System audit trail for compliance';
COMMENT ON TABLE nsn_data IS 'Cached NSN (National Stock Number) lookup data'; 