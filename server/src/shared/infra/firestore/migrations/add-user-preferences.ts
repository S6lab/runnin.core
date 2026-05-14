// Migration: Add user preferences fields to UserProfile entity
// Date: 2025-05-13
// Description: Adds run_alert_preferences and music_preferences JSONB fields

export const updateUserProfileSchema = `
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS run_alert_preferences JSONB DEFAULT '{"paceAlertsEnabled": true, "paceAlertFrequency": "every_km", "hrZoneAlertsEnabled": true, "distanceMilestonesEnabled": true, "distanceMilestones": [5.0, 10.0], "timeMilestonesEnabled": false, "timeMilestones": []}',
ADD COLUMN IF NOT EXISTS music_preferences JSONB DEFAULT '{"serviceEnabled": false, "lastService": "device", "lastVolume": 0.7}';
`;

export const down = `
ALTER TABLE user_profiles
DROP COLUMN IF EXISTS run_alert_preferences,
DROP COLUMN IF EXISTS music_preferences;
`;
