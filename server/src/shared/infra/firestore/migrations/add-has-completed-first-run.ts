// Migration: Add has_completed_first_run field to user profiles
// Date: 2025-05-14
// Description: Adds has_completed_first_run boolean field to track if user has completed their first run
//
// Firestore Note: Since Firestore is a schemaless database, this migration marks the introduction of
// the hasCompletedFirstRun field to UserProfile entity. No database schema changes are required.
// The field will naturally appear in documents when created/updated by the application.

export const updateUserProfileSchema = `

`;

export const down = `

`;
