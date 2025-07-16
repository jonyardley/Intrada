-- Create goals table
CREATE TABLE goals (
    id VARCHAR(255) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'NotStarted',
    start_date VARCHAR(255),
    target_date VARCHAR(255),
    study_ids TEXT NOT NULL DEFAULT '[]',
    tempo_target INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
); 