// Migration: Add has_completed_first_run field to user profiles
// Date: 2025-05-14
// Description: Adds has_completed_first_run boolean field to track if user has completed their first run

export const updateUserProfileSchema = `
ALTER TABLE users
ADD COLUMN IF NOT EXISTS has_completed_first_run BOOLEAN DEFAULT FALSE;
`;

export const down = `
ALTER TABLE users
DROP COLUMN IF EXISTS has_completed_first_run;
`;
