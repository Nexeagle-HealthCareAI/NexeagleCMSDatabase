-- =============================================================================
-- Rollback of 38_CMSDatabase_Keywords.sql
-- Removes the Keywords tables (collected keywords, their daily numbers, topics, the content
-- plan and settings are lost) and the keywords.* permissions.
-- =============================================================================

USE CMSDatabase;
GO

DELETE rp FROM dbo.CmsRolePermissions rp JOIN dbo.CmsPermissions p ON p.PermissionId = rp.PermissionId WHERE p.[Key] LIKE 'keywords.%';
DELETE up FROM dbo.CmsUserPermissions up JOIN dbo.CmsPermissions p ON p.PermissionId = up.PermissionId WHERE p.[Key] LIKE 'keywords.%';
DELETE FROM dbo.CmsPermissions WHERE [Key] LIKE 'keywords.%';
GO

IF OBJECT_ID('dbo.KeywordObservations', 'U') IS NOT NULL DROP TABLE dbo.KeywordObservations;
IF OBJECT_ID('dbo.KeywordContent', 'U') IS NOT NULL DROP TABLE dbo.KeywordContent;
IF OBJECT_ID('dbo.Keywords', 'U') IS NOT NULL DROP TABLE dbo.Keywords;
IF OBJECT_ID('dbo.KeywordTopics', 'U') IS NOT NULL DROP TABLE dbo.KeywordTopics;
IF OBJECT_ID('dbo.KeywordSourceRuns', 'U') IS NOT NULL DROP TABLE dbo.KeywordSourceRuns;
IF OBJECT_ID('dbo.KeywordSettings', 'U') IS NOT NULL DROP TABLE dbo.KeywordSettings;
PRINT 'Keywords tables removed.';
GO
