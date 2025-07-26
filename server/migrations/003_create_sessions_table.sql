-- Create sessions table
CREATE TABLE sessions (
    id VARCHAR(255) PRIMARY KEY,
    goal_ids TEXT NOT NULL DEFAULT '[]',
    intention TEXT NOT NULL,
    notes TEXT,
    session_state VARCHAR(50) NOT NULL DEFAULT 'NotStarted',
    start_time VARCHAR(255),
    end_time VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);