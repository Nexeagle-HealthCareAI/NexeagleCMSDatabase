-- =============================================================================
-- Rollback for 31_CMSDatabase_DocComments.sql
-- =============================================================================
-- Removes comments on documents. EVERY comment and its notifications are
-- deleted. Take a backup first. Documents themselves are untouched.
-- =============================================================================

USE CMSDatabase;
GO

IF OBJECT_ID('dbo.DocNotifications', 'U') IS NOT NULL   DROP TABLE dbo.DocNotifications;
IF OBJECT_ID('dbo.DocCommentMentions', 'U') IS NOT NULL DROP TABLE dbo.DocCommentMentions;
IF OBJECT_ID('dbo.DocComments', 'U') IS NOT NULL        DROP TABLE dbo.DocComments;
GO
