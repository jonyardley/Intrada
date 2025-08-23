-- Add duration_in_seconds column to sessions table
ALTER TABLE sessions ADD COLUMN duration_in_seconds INTEGER;

-- Update existing ended sessions to have a default duration (0 seconds)
UPDATE sessions 
SET duration_in_seconds = 0 
WHERE session_state = 'Ended' AND duration_in_seconds IS NULL;
