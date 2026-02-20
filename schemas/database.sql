-- Scoreboard API Database Schema
-- Version: 1.0.0
-- Compatible: PostgreSQL 14+

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Users table
CREATE TABLE users (
    user_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(32) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    current_score INTEGER NOT NULL DEFAULT 0 CHECK (current_score >= 0),
    total_actions INTEGER NOT NULL DEFAULT 0 CHECK (total_actions >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_users_score ON users(current_score DESC);
CREATE INDEX idx_users_updated ON users(updated_at);

-- Action events (audit trail)
CREATE TABLE action_events (
    event_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    action_type VARCHAR(50) NOT NULL,
    action_idempotency_key VARCHAR(64) NOT NULL UNIQUE,
    payload_hash VARCHAR(64) NOT NULL,
    points_awarded INTEGER NOT NULL CHECK (points_awarded > 0),
    client_timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    server_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    verification_method VARCHAR(10) NOT NULL DEFAULT 'HMAC' 
        CHECK (verification_method IN ('HMAC', 'NONE', 'OAUTH')),
    ip_address INET,
    user_agent TEXT,
    
    CONSTRAINT chk_client_time_future CHECK (client_timestamp < server_timestamp + INTERVAL '1 minute'),
    CONSTRAINT chk_client_time_past CHECK (client_timestamp > server_timestamp - INTERVAL '5 minutes')
);

CREATE INDEX idx_action_events_user_time ON action_events(user_id, server_timestamp DESC);
CREATE INDEX idx_action_events_type_time ON action_events(action_type, server_timestamp);
CREATE INDEX idx_action_events_server_time ON action_events(server_timestamp);

-- Score ledger (immutable history)
CREATE TABLE score_ledger (
    ledger_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES action_events(event_id) ON DELETE CASCADE,
    previous_score INTEGER NOT NULL CHECK (previous_score >= 0),
    new_score INTEGER NOT NULL CHECK (new_score >= 0),
    delta INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT chk_score_math CHECK (new_score = previous_score + delta)
);

CREATE INDEX idx_ledger_user_time ON score_ledger(user_id, created_at DESC);
CREATE INDEX idx_ledger_event ON score_ledger(event_id);

-- Trigger to auto-update users.current_score
CREATE OR REPLACE FUNCTION update_user_score()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE users 
    SET current_score = NEW.new_score,
        total_actions = total_actions + 1,
        updated_at = NOW()
    WHERE user_id = NEW.user_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_user_score
AFTER INSERT ON score_ledger
FOR EACH ROW
EXECUTE FUNCTION update_user_score();

-- Comments for documentation
COMMENT ON TABLE users IS 'Core user profiles with denormalized score cache';
COMMENT ON TABLE action_events IS 'Immutable audit log of all score-changing actions';
COMMENT ON TABLE score_ledger IS 'Event-sourced history of all score changes';