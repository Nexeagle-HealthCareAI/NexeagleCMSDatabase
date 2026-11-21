-- =============================================================================
-- Rollback for 30_CMSDatabase_WorkChat.sql
-- =============================================================================
-- Removes team chat. EVERY conversation, message and notification is deleted.
-- Take a backup first.
-- =============================================================================

USE CMSDatabase;
GO

IF OBJECT_ID('dbo.WorkNotifications', 'U') IS NOT NULL DROP TABLE dbo.WorkNotifications;
IF OBJECT_ID('dbo.WorkChatMentions', 'U')  IS NOT NULL DROP TABLE dbo.WorkChatMentions;
IF OBJECT_ID('dbo.WorkChatMessages', 'U')  IS NOT NULL DROP TABLE dbo.WorkChatMessages;
IF OBJECT_ID('dbo.WorkChatMembers', 'U')   IS NOT NULL DROP TABLE dbo.WorkChatMembers;
IF OBJECT_ID('dbo.WorkChatChannels', 'U')  IS NOT NULL DROP TABLE dbo.WorkChatChannels;
GO
