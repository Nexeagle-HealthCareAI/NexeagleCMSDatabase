-- =============================================================================
-- Rollback of 36_CMSDatabase_Social.sql
-- Removes the Social tables (posts, drafts, comments, messages, lead links and ad
-- numbers in them are lost; CRM leads made from them stay) and the social.* permissions.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId WHERE p.[Key] LIKE 'social.%';
DELETE up FROM dbo.CmsUserPermissions up JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId WHERE p.[Key] LIKE 'social.%';
DELETE FROM dbo.CmsPermissions WHERE [Key] LIKE 'social.%';
GO

IF OBJECT_ID('dbo.SocialAdStats', 'U') IS NOT NULL DROP TABLE dbo.SocialAdStats;
IF OBJECT_ID('dbo.SocialLeadForms', 'U') IS NOT NULL DROP TABLE dbo.SocialLeadForms;
IF OBJECT_ID('dbo.SocialLeads', 'U') IS NOT NULL DROP TABLE dbo.SocialLeads;
IF OBJECT_ID('dbo.SocialNotes', 'U') IS NOT NULL DROP TABLE dbo.SocialNotes;
IF OBJECT_ID('dbo.SocialMessages', 'U') IS NOT NULL DROP TABLE dbo.SocialMessages;
IF OBJECT_ID('dbo.SocialContacts', 'U') IS NOT NULL DROP TABLE dbo.SocialContacts;
IF OBJECT_ID('dbo.SocialComments', 'U') IS NOT NULL DROP TABLE dbo.SocialComments;
IF OBJECT_ID('dbo.SocialQueueSlots', 'U') IS NOT NULL DROP TABLE dbo.SocialQueueSlots;
IF OBJECT_ID('dbo.SocialDrafts', 'U') IS NOT NULL DROP TABLE dbo.SocialDrafts;
IF OBJECT_ID('dbo.SocialPostStats', 'U') IS NOT NULL DROP TABLE dbo.SocialPostStats;
IF OBJECT_ID('dbo.SocialPosts', 'U') IS NOT NULL DROP TABLE dbo.SocialPosts;
IF OBJECT_ID('dbo.SocialAccountDaily', 'U') IS NOT NULL DROP TABLE dbo.SocialAccountDaily;
IF OBJECT_ID('dbo.SocialAccounts', 'U') IS NOT NULL DROP TABLE dbo.SocialAccounts;
GO
