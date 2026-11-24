-- =============================================================================
-- Rollback for 33_CMSDatabase_WorkItemMentions.sql
-- =============================================================================
-- Removes tagging in work items: every tag and its notifications are deleted.
-- Comments, descriptions and their text (with the @names in it) are untouched.
-- =============================================================================

USE CMSDatabase;
GO

IF OBJECT_ID('dbo.WorkItemNotifications', 'U') IS NOT NULL DROP TABLE dbo.WorkItemNotifications;
IF OBJECT_ID('dbo.WorkItemMentions', 'U') IS NOT NULL      DROP TABLE dbo.WorkItemMentions;
GO
