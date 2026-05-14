// Migration: Add user preferences fields to UserProfile entity
// Date: 2025-05-13
// Description: Adds run_alert_preferences and music_preferences JSONB fields
//
// Firestore Note: Since Firestore is a schemaless database, this migration marks the introduction of
// nested preference objects to UserProfile entity. No database schema changes are required.
// The fields will naturally appear in documents when created/updated by the application.

export const updateUserProfileSchema = `

`;

export const down = `

`;
